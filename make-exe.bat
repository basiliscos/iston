set PERL5LIB=d:\basiliscos\group-iston\iston\lib
pp -l lib -M if -M Text::CSV_PP -M AnyEvent::Impl::EV -M AntTweakBar -M AntTweakBar::Type  -M Iston::Object -M Iston::Vertex -M Iston::Vector -M Iston::Loader -M Iston::Application -M Iston::Drawable -M Iston::History -M Iston::Triangle -M Iston::TrianglePath  -M Iston::Utils -M Iston::Application::Analyzer -M Iston::Application::Observer -M Iston::History::Record -M Iston::Object::HTM -M Iston::Object::ObservationPath -M Iston::Analysis::Projections -M Iston::Analysis::Aberrations -M Iston::Payload -o iston.exe bin/iston.pl

