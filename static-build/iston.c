#include <EXTERN.h>
#include <perl.h>
#include <stdlib.h>


EXTERN_C void xs_init (pTHX);

static PerlInterpreter *my_perl;

int main (int argc, char **argv, char **env)
 {
   char *my_argv[] = { "", "-Ilib", "lib/iston.pl" };
   char *my_env[] = {"ISTON_PORTABLE=1", NULL};
   int my_argc = 3;
   int i;
   fprintf( stderr, "initializing perl...\n");
   PERL_SYS_INIT3(&argc,&argv,&env);
   my_perl = perl_alloc();
   perl_construct( my_perl );
   char **united_argv = (char**) malloc(sizeof(char*) * (my_argc + argc) );
   for(i = 0; i < my_argc; i++) {
       united_argv[i] = my_argv[i];
   }
   for(i = 1; i < argc; i++) {
       united_argv[i+my_argc-1] = argv[i];
   }
   int united_argc = my_argc + argc - 1;
   /*
   for(i = 0; i < united_argc; i++) {
       printf("[%d/%d] : %s \n", i, united_argc, united_argv[i]);
   }
   */
   perl_parse(my_perl, xs_init, united_argc, united_argv, my_env);
   PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
   fprintf( stderr, "running perl perl...\n");
   perl_run(my_perl);
   perl_destruct(my_perl);
   perl_free(my_perl);
   free(united_argv);
   PERL_SYS_TERM();
}

