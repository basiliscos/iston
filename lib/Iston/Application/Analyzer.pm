package Iston::Application::Analyzer;
$Iston::Application::Analyzer::VERSION = '0.10';
use 5.16.0;

use AntTweakBar qw/:all/;
use AnyEvent;
use Carp;
use Iston;
use File::Find::Rule;
use Function::Parameters qw(:strict);
use List::MoreUtils qw/any uniq/;
use List::Util qw/max/;
use Math::Trig;
use Moo;
use OpenGL qw(:all);
use Path::Tiny;
use POSIX qw/strftime/;
use SDL::Events qw/:all/;
use SDL::Surface;
use SDL::Video;
use SDLx::Surface;

use aliased qw/AntTweakBar::Type/;
use aliased qw/Iston::History/;
use aliased qw/Iston::Analysis::Aberrations/;
use aliased qw/Iston::Analysis::AngularVelocity/;
use aliased qw/Iston::Analysis::Projections/;
use aliased qw/Iston::Analysis::Visibility/;
use aliased qw/Iston::Object::HTM/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Object::SphereVectors::GeneralizedVectors/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Vector/;

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
has _analysis_dumper       => (is => 'rw', default => sub { sub{ } });
has _source_sphere_vectors => (is => 'rw');
has _region_path           => (is => 'rw');
has _points_of_interes     => (is => 'rw', default => sub { [] });

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
    my $r = Vector->new(values => $htm->triangles->[0]->vertices->[0]->values)->length;
    my $scale_to = 1/($r/$self->max_boundary);
    $htm->scale($scale_to);
    $htm->level(3);
    $htm->shader($self->shader_for->{object});
    $htm->notifyer($self->_notifyer);
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
    $observation_path->shader($self->shader_for->{object});
    $observation_path->scale($scale_to*1.02);
    my $sphere_vectors = VectorizedVertices->new(
        vertices       => $observation_path->vertices,
        vertex_indices => $observation_path->sphere_vertex_indices,
        default_color  => [1.0, 0.0, 0.0, 0.0],
    );
    $observation_path->sphere_vectors($sphere_vectors);
    $self->observation_path($observation_path);
    $self->_source_sphere_vectors($sphere_vectors);

    my $projections = Projections->new(
        observation_path => $observation_path,
        htm              => $self->htm,
    );
    $self->htm->walk_triangles(sub { $_[0]->enabled(0) });
    $projections->distribute_observation_timings;
    $self->projections($projections);

    my $dumper = sub {
        my $aberrations = Aberrations->new(
            sphere_vectors => $observation_path->sphere_vectors,
        );
        my $angular_velocity = AngularVelocity->new(
            observation_path => $observation_path,
            sphere_vectors   => $self->_source_sphere_vectors,
        );
        my $analisys_dir = path("${history_path}-analysis");
        $analisys_dir->mkpath;
        my $timings_projections_path = path($analisys_dir, "timing-projections.txt");
        my $tpp_fh = $timings_projections_path->filehandle('>');
        $projections->dump_analisys($tpp_fh);

        my $aberrations_path = path($analisys_dir, "aberrations.csv");
        my $aberrations_fh = $aberrations_path->filehandle('>');
        $aberrations->dump_analisys($aberrations_fh, $observation_path);
        $self->aberrations($aberrations);
        my $angular_velocity_fh = path($analisys_dir, "anglual-velocity.csv")
            ->filehandle('>');
        $angular_velocity->dump_analisys($angular_velocity_fh);

        if($self->_region_path){
            my $colors_on_step = $self->_analyze_visibility($self->_region_path);
            (my $region_name = path($self->_region_path)->basename) =~ s/\..+$//;
            my $visibility_path = path($analisys_dir, "${region_name}-visibility.csv");
            my $visibility_fh = $visibility_path->filehandle('>');
            for my $step (0 .. @$colors_on_step-1){
                my $colors = join(', ',
                                  map  { sprintf('%X', $_) }
                                  sort { $a <=> $b }
                                  @{ $colors_on_step->[$step] }
                );
                say $visibility_fh "$step, $colors";
            }
        }
        my $point_of_interes = $self->_points_of_interes;
        if(@$point_of_interes) {
            path($analisys_dir,'points-of-interes.txt')
                ->spew(join(', ', @$point_of_interes));
        }
        $history_path->copy(path($analisys_dir, 'history.csv'));
    };
    $self->_analysis_dumper($dumper);

    $self->_try_visualize_htm(2); # durations projection
    my $last_point = @{ $observation_path->history->records };
    $self->settings_bar->set_variable_params(
        'current_point',
        max => "$last_point",
    );

    $self->active_record_idx(0);
    $self->settings_bar->set_variable_params('current_point', readonly => 'false');
    $self->settings_bar->refresh;
    $self->_region_path('');
    $self->_points_of_interes([]);
    # $self->_start_replay;
}


sub _pause_unpause {
    my ($self, $value) = @_;
    $self->timer($value);
    my $bar = $self->settings_bar;
    if($value) {
        my $step_function = $self->step_end_function;
        if(!$step_function) {
            $self->_start_replay;
        }
        $self->step_end_function->();
        $bar->set_variable_params('current_point', readonly => 'true');
    }else {
        $bar->set_variable_params('current_point', readonly => 'false')
    }
}

sub _build_menu {
    my $self = shift;
    my $bar = $self->settings_bar;
    $bar->set_bar_params(
        size        => '350 ' . ($self->height - 50),
        valueswidth => '200');

    # visibility group
    my @items = (
        main_object      => { label => 'Object' },
        htm              => { label => 'HTM', key => 'h'},
        observation_path => { label => 'Observation path'},
    );
    for my $idx (0 .. @items/2-1) {
        my $object_name = $items[$idx*2];
        my $data        = $items[$idx*2 + 1];
        my $label       = $data->{label};
        my $key         = $data->{key} ;
        my $definition  = {
            group => 'Visibility',
            label => $label,
            ($key ? (key => $key) : () ),
        };
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
            definition => $definition,
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
        mode       => 'rw',
        name       => "autoplay",
        type       => 'bool',
        cb_read    => sub { $self->timer },
        cb_write   => sub { $self->_pause_unpause(shift) },
        definition => " label='Autoplay' group='Replay History' key=SPACE ",
    );
    $bar->add_variable(
        mode       => 'rw',
        name       => "current_point",
        type       => 'integer',
        cb_read    => sub { ($self->active_record_idx // 0) + 1 },
        cb_write   => sub {
            my $value = shift;
            $self->active_record_idx($value-1);
            $self->_rotate_active;
        },
        definition => " group='Replay History' label='Current point' min=1 step=1 readonly=true ",
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "current_point_info",
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
        definition => " group='Replay History' label='Point info' ",
    );
    $bar->add_variable(
        mode       => 'rw',
        name       => 'interes_mark',
        type       => 'bool',
        cb_read    => sub {
            my $current_point = $self->active_record_idx;
            return any { $_ eq $current_point } @{ $self->_points_of_interes };
        },
        cb_write   => sub {
            my $current_point = $self->active_record_idx;
            if(defined $current_point) {
                push @{ $self->_points_of_interes }, $current_point;
            }
        },
        definition => " group='Replay History' label='interes mark' key='i' ",
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
    $htm->lighting(1);
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
    $bar->set_variable_params('HTM', opened => 'false');

    # models group
    my @models =
        map  { { path => $_ } }
        sort { $a cmp $b }
        grep { /\.obj$/i }
        path($self->models_path)->children;
    my %history_of = map { $_->{path}->basename => $_ }
        @models;

    my @histories = map { path($_) }
        File::Find::Rule->file
        ->name( "history_*.csv" )
        ->in( path(".") );
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
            map {
                my $history_file = $_;
                my $parent = $history_file->parent->basename;
                $history_file->basename =~ /^history_(\d+)_(.+)\.csv$/
                    ? "$parent/" . strftime('%Y-%m-%d %H:%M:%S', localtime($1))
                    : $_
            } @{ $_->{histories} }
        );
        my $history_type = Type->new("history_for" . $_->{path}, \@history_names);
        $_->{history_type} = $history_type;

        (my $region_basename = $_->{path}->basename) =~ s/.obj//;
        my @regions =
            sort { $a cmp $b}
            map  { path($_) }
            File::Find::Rule->file
            ->name( "${region_basename}*.png" )
            ->in( $_->{path}->parent );
        $_->{regions} = \@regions;
        my @region_names = ("choose region", map { $_->basename } @regions );
        my $region_type = Type->new("region_for_" . $_->{path}, \@region_names);
        $_->{region_type} = $region_type;
    }
    my @model_names = ("choose model", map { $_->{path}->basename } @models);
    my $model_type = Type->new("available_models", \@model_names);
    my $model_index = 0;
    $bar->add_variable(
        mode       => 'rw',
        name       => "model",
        type       => $model_type,
        cb_read    => sub { $model_index },
        cb_write   => sub {
            my $new_index = shift;
            return if $new_index == 0; # skip "choose model" index;
            my $prev_model_index = $model_index;
            $model_index = $new_index;
            my $model = $models[ $model_index - 1];
            my $history_type = $model->{history_type};
            $bar->remove_variable('history') if($prev_model_index);
            my $history_index = 0;
            $bar->add_variable(
                mode       => 'rw',
                name       => "history",
                type       => $history_type,
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

            my $region_index = 0;
            $bar->remove_variable('region_of_interest') if($prev_model_index);
            $bar->add_variable(
                mode       => 'rw',
                name       => "region_of_interest",
                type       => $model->{region_type},
                cb_read    => sub { $region_index },
                cb_write   => sub {
                    $region_index = shift;
                    return if $region_index== 0; # skip "choose region" index;
                    my $model = $models[ $model_index - 1];
                    my $region_path = $model->{regions}->[ $region_index - 1];
                    $self->_region_path($region_path);
                },
                definition => " group='Model' ",
            );
        },
        definition => " group='Model' ",
    );

    my $angular_distance = 0;
    $bar->add_variable(
        mode       => 'rw',
        name       => "generalization_distance",
        type       => "number",
        cb_read    => sub { $angular_distance },
        cb_write   => sub {
            $angular_distance = shift;
            return unless $self->observation_path;

            my $sv = $angular_distance
                ? GeneralizedVectors->new(
                    distance       => deg2rad($angular_distance),
                    source_vectors => $self->_source_sphere_vectors,
                    default_color  => [0.0, 0.0, 0.75, 0.0]
                )
                : $self->_source_sphere_vectors;
            $self->observation_path->sphere_vectors($sv);
        },
        definition => {
            min   => '0',
            max   => '360',
            label => 'distance',
            group => 'Analysis',
        },
    );

    $bar->add_variable(
        mode       => 'rw',
        name       => "spin_detection",
        type       => 'bool',
        cb_read    => sub {
            my $observation_path = $self->observation_path;
            return $observation_path && $observation_path->sphere_vectors->spin_detection;
        },
        cb_write   => sub {
            my $observation_path = $self->observation_path;
            if($observation_path) {
                my $value = shift;
                $observation_path->sphere_vectors->spin_detection($value);
            }
        },
        definition => {
            label => 'spin detection',
            group => 'Analysis',
        },
    );

    # dump analisys button
    $bar->add_button(
        name       => "dump",
        cb         => sub { $self->_analysis_dumper->() },
        definition => {
            label => 'write results',
        },
    );
}

method _analyze_visibility($texture_path) {
    say "loading custom texture $texture_path for visibility analisys";
    my $records_count = @{ $self->history->records };
    my $object = $self->main_object;
    my @backup_properties = qw/lighting texture_file/;
    my @backups = map { $object->$_ } @backup_properties;
    my $previous_lighting = $object->lighting;
    $object->lighting(0);
    $object->texture_file($texture_path);
    my ($w, $h) = map { $self->$_ } qw/width height/;

    my $visibility = Visibility->new(pattern => $object->texture);

    my @colors_on_step;
    for (my $s = 0; $s < $records_count; $s++) {
        $colors_on_step[$s] = [];
        $self->_rotate_objects($s);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        $object->draw_function->();
        my $image = SDL::Surface->new(
            SDL_SWSURFACE, $w, $h, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000,
        );
        my $pix_buffer = $image->get_pixels_ptr;
        glReadPixels_s(0, 0, $w, $h, GL_RGBA, GL_UNSIGNED_BYTE, $pix_buffer);
        my $found_colors = $visibility->find($image);
        $colors_on_step[$s] = $found_colors;
        #SDL::Video::save_BMP( $image, "/tmp/1/$s.bmp" );
        $self->sdl_app->sync;
        glFlush;
    }
    for my $i (0 .. @backup_properties -1 ) {
        my $property = $backup_properties[$i];
        $object->$property($backups[$i]);
    }
    return \@colors_on_step;
}

sub _exit {
    my $self = shift;
    say "...exiting from analyzer";
    $self->sdl_app->stop;
}

method _rotate_objects($idx) {
    my $record = $self->history->records->[$idx];
    my ($x_axis_degree, $y_axis_degree) = map { $record->$_ }
        qw/x_axis_degree y_axis_degree/;
    for (@{ $self->objects }) {
        $_->rotate(0, $x_axis_degree);
        $_->rotate(1, $y_axis_degree);
    }
    my $position = [ map { $record->$_ } map{ "camera_${_}" } qw/x y z/ ];
    $self->camera_position(Vector->new(values => $position));
}

sub _rotate_active {
    my $self = shift;
    my $idx = $self->active_record_idx;
    my $record = $self->history->records->[$idx];
    $self->_rotate_objects($idx);
    $self->observation_path->active_time($record->timestamp);
    $self->settings_bar->refresh;
    $self->redraw_world;
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
        $self->_rotate_active;
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
        my $delay = $sleep_time * $self->time_ratio;
        my $t; $t = AE::timer $delay, 0, sub {
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
            SDLK_w()  => 'rotate_axis_x_ccw',
            SDLK_s()  => 'rotate_axis_x_cw',
            SDLK_a()  => 'rotate_axis_y_cw',
            SDLK_d()  => 'rotate_axis_y_ccw',
            SDLK_q()  => 'terminate_program',
            SDLK_F4() => 'terminate_program',
        };
        my $key = $event->key_sym;
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
                my $max_share_of = {};
                my $min_share_of = {};
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
                        #return unless $max_distance;
                        my $time_share = $t->{payload}->{total_time};
                        my $share = $max_distance
                            ? ($time_share - $min) / $max_distance
                            : 1.0;
                        $t->{payload}->{time_share} = $share;
                        $t->enabled(1);
                    });
                });
                $htm->_prepare_data;
                $htm->lighting(0);
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

version 0.10

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
