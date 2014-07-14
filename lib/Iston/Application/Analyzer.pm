package Iston::Application::Analyzer;
$Iston::Application::Analyzer::VERSION = '0.04';
use 5.12.0;

use AntTweakBar qw/:all/;
use AnyEvent;
use List::Util qw/max/;
use Moo;
use OpenGL qw(:all);
use Path::Tiny;
use SDL::Events qw/:all/;

use aliased qw/AntTweakBar::Type/;
use aliased qw/Iston::History/;
use aliased qw/Iston::Analysis::Aberrations/;
use aliased qw/Iston::Analysis::Projections/;
use aliased qw/Iston::Object::HTM/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Vertex/;

with('Iston::Application');

has main_object            => (is => 'rw');
has models_path            => (is => 'ro', required => 1);
has htm                    => (is => 'lazy');
has projections            => (is => 'rw');
has aberrations            => (is => 'rw');
has observation_path       => (is => 'rw');
has active_record_idx      => (is => 'rw');
has time_ratio             => (is => 'rw', default => sub { 1.0 });
has timer                  => (is => 'rw');
has step_function          => (is => 'rw');
has step_end_function      => (is => 'rw');
has _commands              => (is => 'lazy');
has _htm_visualizers       => (is => 'lazy');
has _htm_visualizer_index  => (is => 'rw', default => sub { 0 });

sub _build_menu;

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->_build_menu;
}

sub _build_htm {
    my $self = shift;
    my $htm = HTM->new;
    # $htm->mode('mesh');
    my $r = Vertex->new([0, 0, 0])->vector_to($htm->triangles->[0]->vertices->[0])->length;
    my $scale_to = 1/($r/$self->max_boundary);
    $htm->scale($scale_to); # 2.5
    $htm->level(3);
    return $htm;
}

sub objects {
    my $self = shift;
    [map { $_ ? $_ : () } ($self->main_object, $self->htm, $self->observation_path) ];
}

sub _load_object {
    my ($self, $object_path, $history_path) = @_;
    my $object = $self->load_object($object_path);
    $self->main_object($object);
    my $history = History->new( path => $history_path)->load;
    $self->history($history);

    my $r1 = ($object->radius) * $object->scale;
    my $r2 = $self->htm->radius;
    my $scale_to = $r1/$r2;
    $self->htm->scale($scale_to*1.01);
    $self->htm->clear_draw_function;

    my $observation_path = ObservationPath->new(history => $history);
    $observation_path->scale($scale_to*1.01);
    $self->observation_path($observation_path);

    my $projections = Projections->new(
        observation_path => $observation_path,
        htm              => $self->htm,
    );
    $projections->distribute_observation_timings;

    my $analisys_path = "${history_path}-analisys.txt";
    open my $analisys_fh, ">:encoding(utf8)", $analisys_path
        or die "Can't open $analisys_path : $!";
    $projections->dump_analisys($analisys_fh);
    $self->projections($projections);

    my $aberrations = Aberrations->new(
        projections => $projections
    );
    my $aberrations_path = "${history_path}-aberations.csv";
    open my $aberrations_fh, ">:encoding(utf8)", $aberrations_path
        or die "Can't open $aberrations_path : $!";
    $aberrations->dump_analisys($aberrations_fh);
    $self->aberrations($aberrations);

    $self->_try_visualize_htm(2); # durations projection

    $self->settings_bar->refresh;

    $self->_start_replay;
}


sub _build_menu {
    my $self = shift;
    my $bar = $self->settings_bar;
    $bar->set_bar_params(
        size        => '350 ' . ($self->height - 50),
        valueswidth => '200');

    # visibility group
    my @items = (
        main_object      => 'Object',
        htm              => 'HTM',
        observation_path => 'Observation path',
    );
    for my $idx (0 .. @items/2-1) {
        my $object_name = $items[$idx*2];
        my $label       = $items[$idx*2 + 1];
        $bar->add_variable(
            mode       => 'rw',
            name       => "vis_$object_name",
            type       => 'bool',
            cb_read    => sub {
                my $object = $self->$object_name;
                return $object && $object->enabled;
            },
            cb_write   => sub {
                my $object = $self->$object_name;
                $object->enabled(shift) if $object;
            },
            definition => " group='Visibility' label='$label' ",
        );
    }

    # Replay history group
    $bar->add_variable(
        mode       => 'rw',
        name       => "time_ratio",
        type       => 'number',
        cb_read    => sub { $self->time_ratio },
        cb_write   => sub { $self->time_ratio(shift) },
        definition => " group='Replay History' label='Time ratio' min=0.1 max=10.0 step=0.01 ",
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "current_point",
        type       => 'string',
        cb_read    => sub {
            my $observation_path = $self->observation_path;
            my $result = "";
            if ($observation_path) {
                my $view_points = @{ $observation_path->vertices };
                my $current_point = $self->active_record_idx;
                my $current_ts = $self->history->records->[$current_point]->timestamp;
                $result = sprintf '%d/%d [%0.4f second]',
                    $current_point+1, $view_points, $current_ts;
            }
            return $result;
        },
        definition => " group='Replay History' label='Current point' ",
    );

    # HTM group
    my $htm_triangles = @{ $self->htm->triangles };
    $bar->add_variable(
        mode       => 'rw',
        name       => "htm_level",
        type       => 'integer',
        cb_read    => sub { $self->htm->level },
        cb_write   => sub { $self->htm->level($_[0]) },
        definition => " group='HTM' label='level' min=0 max=10 ",
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "htm_triangles",
        type       => 'integer',
        cb_read    => sub { scalar(@{ $self->htm->triangles }) },
        definition => " group='HTM' label='triangles' ",
    );
    my $htm = $self->htm;
    my $htm_visualizers = $self->_htm_visualizers;
    my $htm_visualization = Type->new(
        "htm_visualization", [
            map { $htm_visualizers->[$_*2] } (0 .. (@$htm_visualizers-1)/2)
        ]
    );
    $bar->add_variable(
        mode       => 'rw',
        name       => "visualization_mode",
        type       => $htm_visualization,
        cb_read    => sub { $self->_htm_visualizer_index },
        cb_write   => sub { $self->_try_visualize_htm($_[0]) },
        definition => " group='HTM' label='mode' ",
    );

    # models group
    my @models =
        map  { { path => $_ }}
        sort { $a cmp $b }
        grep { /\.obj$/i }
        path($self->models_path)->children;
    my %history_of = map { $_->{path}->basename => $_ }
        @models;

    my @histories =  grep { /\.csv/i } path(".")->children;
    for my $h (@histories) {
        if($h->basename =~ /^history_(\d+)_(.+)\.csv$/) {
            my $model_name = $2;
            if ( exists $history_of{$model_name} ) {
                push @{ $history_of{$model_name}->{histories} }, $h;
            }
        }
    };
    @models = grep { exists $history_of{$_->{path}->basename}->{histories} } @models;
    for (@models) {
        $_->{histories} = [
            sort {$a cmp $b}
            @{ $history_of{$_->{path}->basename}->{histories} }
        ];
        my @history_names = (
            "choose history",
            map { $_->basename } @{ $_->{histories} },
        );
        my $history_type = Type->new("history_for" . $_->{path}->basename,
                                     \@history_names);
        $_->{type} = $history_type;
    }
    my @model_names = ("choose model", map { $_->{path}->basename } @models);
    my $model_type = Type->new("available_models", \@model_names);
    my $model_index = 0;
    my $history_index = 0;
    my $already_has_history = 0;
    $bar->add_variable(
        mode       => 'rw',
        name       => "model",
        type       => $model_type,
        cb_read    => sub { $model_index },
        cb_write   => sub {
            $model_index = shift;
            return if $model_index == 0; # skip "choose model" index;
            my $model = $models[ $model_index - 1];
            my $type = $model->{type};
            $bar->remove_variable('history') if($already_has_history);
            $bar->add_variable(
                mode       => 'rw',
                name       => "history",
                type       => $type,
                cb_read    => sub { $history_index },
                cb_write   => sub {
                    $history_index = shift;
                    return if $history_index== 0; # skip "choose history" index;
                    my $model = $models[ $model_index - 1];
                    my $model_path = $model->{path};
                    my $history_path = $model->{histories}->[ $history_index - 1];
                    say "goint to load $model_path and it's history at $history_path";
                    $self->_load_object($model_path, $history_path);
                },
                definition => " group='Model' ",
            );
            $history_index = 0;
            $already_has_history = 1;
        },
        definition => " group='Model' ",
    );
}

sub _exit {
    my $self = shift;
    say "...exiting from analyzer";
    $self->cv_finish->send;
}

sub _start_replay {
    my $self = shift;
    my ($last_time, $record, $sleep_time, $history_object);
    my $initialize = sub {
        $last_time = 0;
        $self->active_record_idx(0);
        $record = $self->history->records->[$self->active_record_idx];
        $sleep_time = $record->timestamp - $last_time;
        $history_object = $self->history;
    };
    $initialize->();
    my $renew_timer_funciton;
    my $step_end_function = sub {
        if ($record) {
            $sleep_time = $record->timestamp - $last_time;
            $renew_timer_funciton->();
        } else {
            my $pause; $pause = AE::timer 3, 0, sub {
                undef $pause;
                $self->_start_replay;
            }
        }
    };
    $self->step_end_function($step_end_function);
    my $step = sub {
        return if($history_object != $self->history or !defined($record));
        my ($x_axis_degree, $y_axis_degree) = map { $record->$_ }
            qw/x_axis_degree y_axis_degree/;
        for (@{ $self->objects }) {
            $_->rotate(0, $x_axis_degree);
            $_->rotate(1, $y_axis_degree);
        }
        $self->camera_position([
            map { $record->$_ } qw/camera_x camera_y camera_z/
        ]);
        $self->observation_path->active_time($record->timestamp);
        $self->settings_bar->refresh;
        $self->refresh_world;

        $last_time = $record->timestamp;
        my $idx = $self->active_record_idx;
        $record = $self->history->records->[++$idx];
        $idx-- unless($record); # let index always point to the last record
        $self->active_record_idx($idx);
        $self->step_end_function->();
    };
    $self->step_function($step);
    $renew_timer_funciton = sub {
        # timer = 0 check, i.e. stop replay has been pressed
        return if(defined($self->timer) && $self->timer == 0);
        my $t; $t = AE::timer $sleep_time * $self->time_ratio, 0, sub {
            $self->step_function->();
        };
        $self->timer($t);
    };
    $renew_timer_funciton->();
}

sub process_event {
    my ($self, $event) = @_;
    my $action;
    AntTweakBar::eventSDL($event);
    if ($event->type == SDL_KEYUP) {
        my $dispatch_table = {
            'w' => 'rotate_axis_x_ccw',
            's' => 'rotate_axis_x_cw',
            'a' => 'rotate_axis_y_cw',
            'd' => 'rotate_axis_y_ccw',
            '+' => 'increase_step_delay',
            '-' => 'decrease_step_delay',
            'i' => 'increase_htm_details',
            'I' => 'decrease_htm_details',
            ' ' => 'pause_unpause',
            'q' => 'terminate_program',
        };
        my $key = chr($event->key_sym);
        $key = uc($key) if($event->key_mod & KMOD_SHIFT);
        my $command = $dispatch_table->{$key};
        $action = $self->_commands->{$command} if defined $command;
    }
    elsif ($event->type == SDL_QUIT) {
        $action = $self->_commands->{'terminate_program'};
    }
    if ($action) {
        $action->();
    }
}

sub _try_visualize_htm {
    my ($self, $visualized_idx ) = @_;
    my $render = $self->_htm_visualizers->[$visualized_idx * 2 + 1];
    if ($render->()) {
        $self->_htm_visualizer_index($visualized_idx);
        $self->htm->clear_draw_function;
    }
}

sub _build__htm_visualizers {
    my $self = shift;
    my $htm = $self->htm;
    my @htm_visualizers = (
        'sphere' => sub {
            my $max_level = max keys %{ $htm->levels_cache };
            for my $level (0 .. $max_level) {
                my $triangles = $htm->levels_cache->{$level};
                for my $t (@$triangles){
                    $t->enabled(1);
                    $t->mode('normal') unless($t->mode eq 'normal' );
                }
            }
            return 1;
        },
        'sphere_mesh' => sub {
            my $max_level = max keys %{ $htm->levels_cache };
            for my $level (0 .. $max_level) {
                my $triangles = $htm->levels_cache->{$level};
                for my $t (@$triangles){
                    $t->enabled(1);
                    $t->mode('mesh') unless($t->mode eq 'mesh');
                }
            }
            return 1;
        },
        'duration projections' => sub {
            my $projections = $self->projections;
            if($projections) {
                my $max_level = max keys %{ $htm->levels_cache };
                my $max_share_of = {};
                my $min_share_of = {};
                for my $level (0 .. $max_level) {
                    my $triangles = $htm->levels_cache->{$level};
                    $_->enabled(0) for (@$triangles);
                }
                $projections->walk( sub {
                    my ($vertex_index, $level, $path) = @_;
                    $max_share_of->{$level} //= 0;
                    $path->apply( sub {
                        my ($t, $path) = @_;
                        my $time_share = $t->payload->{total_time};
                        $max_share_of->{$level} = $time_share
                            if $max_share_of->{$level} < $time_share;
                        $min_share_of->{$level} = $time_share
                            if(!exists $min_share_of->{$level} ||
                            $min_share_of->{$level} > $time_share);
                    })
                });
                $projections->walk( sub {
                    my ($vertex_index, $level, $path) = @_;
                    $path->apply( sub {
                        my ($t) = @_;
                        my ($min, $max) = (
                            $min_share_of->{$level},
                            $max_share_of->{$level},
                        );
                        my $max_distance = $max - $min;
                        return unless $max_distance;
                        my $time_share = $t->{payload}->{total_time};
                        my $share = ($time_share - $min) / $max_distance;
                        # say "$path share: $share, min: $min, max: $max, level: $level";
                        my $diffuse_ambient = [ $share, $share, 0, 1 ];
                        $t->diffuse($diffuse_ambient);
                        $t->ambient($diffuse_ambient);
                        $t->specular([0.1, 0.1, 0.1, 0.1]);
                        $t->shininess(0.8);

                        $t->mode('normal') unless($t->mode eq 'normal' );
                        $t->enabled(1);
                        $t->clear_draw_function;
                    });
                });
                return 1;
            }
        },
    );
    return \@htm_visualizers;
}

sub _build__commands {
    my $self = shift;
    my $rotate_step = 2;
    my $rotation = sub {
        my ($axis, $step) = @_;
        my $subject = $self->htm;
        return sub {
            my $value = $subject->rotate($axis);
            $value += $step;
            $value %= 360;
            $subject->rotate($axis, $value);
        }
    };
    my $adjust_time_ration = sub {
        my $value = shift;
        return sub {
            $self->time_ratio( $self->time_ratio * $value );
        };
    };
    my $switch_mode = sub {
        my $subject = $self->main_object // $self->htm;
        my $new_mode = $subject->mode eq 'normal'
            ? 'mesh'
            : 'normal';
        $subject->mode($new_mode);
    };
    my $detalize = sub {
        my $level_delta = shift;
        return sub {
            my $level = $self->htm->level;
            $self->htm->level($level + $level_delta);
        };
    };
    my $pause_unpause = sub {
        if($self->timer) {
            $self->timer(0);
        }else {
            $self->timer(1);
            $self->step_end_function->();
        }
    };
    my $commands = {
        'rotate_axis_x_ccw'    => $rotation->(0, -$rotate_step),
        'rotate_axis_x_cw'     => $rotation->(0, $rotate_step),
        'rotate_axis_y_cw'     => $rotation->(1, -$rotate_step),
        'rotate_axis_y_ccw'    => $rotation->(1, $rotate_step),
        'increase_step_delay'  => $adjust_time_ration->(1.1),
        'decrease_step_delay'  => $adjust_time_ration->(0.95),
        'increase_htm_details' => $detalize->(1),
        'decrease_htm_details' => $detalize->(-1),
        'terminate_program'    => sub { $self->_exit },
        'pause_unpause'        => $pause_unpause,
    };
    return $commands;
};

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Application::Analyzer

=head1 VERSION

version 0.04

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
