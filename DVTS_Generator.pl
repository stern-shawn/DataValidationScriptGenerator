# This make DVTS
# You like

use strict;
use warnings;
use XML::Simple qw(:strict);
use Data::Dumper;
use File::Basename;

my $runXML = $ARGV[0];
#my $outfile = $ARGV[1];
my $dirName = dirname($runXML);
#print "$dirName\n";
chdir $dirName;

my $runConfig = XMLin($runXML, ForceArray => [ 'Action', 'Loop' , 'Test' , 'var' ], KeyAttr => [ ]);

# Grab all defines before getting freaky
my @allDefinitions = glob("*define.xml");

# Check for a parent generic directory and grab any xmls there before returning to current script directory
if (chdir "../generic") {
    push @allDefinitions, glob("*define.xml");
    chdir $dirName;
}
# print @allDefinitions;

# Go through all defines. Make sure the 'generic' xml is the first element to be processed. Reorder as needed.
for (my $i=0; $i < 0+@allDefinitions; $i++) {
    if ($allDefinitions[$i] =~ /generic/) {
        #print "-i- I FOUND A GENERIC AT INDEX $i\n";
        my $temp = $allDefinitions[0];
        $allDefinitions[0] = $allDefinitions[$i];
        $allDefinitions[$i] = $temp;
    }
}
#print @allDefinitions;

my $definitions;

# If we grabbed a generic XML, make sure to pull it from the properly parent directory...
if ($allDefinitions[0] =~ /generic/) {
    $definitions = XMLin("../generic/$allDefinitions[0]", ForceArray => [ 'Define' , 'PostTest' , 'PreTest' ], KeyAttr => [ 'id' , 'loop' ]);
} else {
    $definitions = XMLin($allDefinitions[0], ForceArray => [ 'Define' , 'PostTest' , 'PreTest' ], KeyAttr => [ 'id' , 'loop' ]);
}

# Mash any/all define xml data into one large hashref... because it might work... edit: it did work.
# This is to support Chip's request for having a generic product defines XML for standard tests, then a module-specific define XML...
if (0+@allDefinitions > 1) {
    for (my $i=1; $i < 0+@allDefinitions; $i++) {
        my $tempDefinitions = XMLin($allDefinitions[$i], ForceArray => [ 'Define' , 'PostTest' , 'PreTest' ], KeyAttr => [ 'id' , 'loop' ]);

        print "-i- Attempting to merge $allDefinitions[$i]'s contents with existing $allDefinitions[0] values... round: $i\n";

        # Okay... lets use Hash Slices (look it up on PerlMonks) to edit our $definitions hashref in-place and write in any non-conflicting 
        # new keys. I believe any existing keys will be overwritten using this implementation. Edit: yes, last thing in overwrites what was previously there.        

        @{$definitions->{Tests}->{Test}}{keys $tempDefinitions->{Tests}->{Test}} = values $tempDefinitions->{Tests}->{Test};

        @{$definitions->{Loops}->{Loop}}{keys $tempDefinitions->{Loops}->{Loop}} = values $tempDefinitions->{Loops}->{Loop};

        @{$definitions->{Defines}->{Define}}{keys $tempDefinitions->{Defines}->{Define}} = values $tempDefinitions->{Defines}->{Define};

        #print Dumper($definitions);
        print "-i- Merge complete, we are one\n";

        # Tried these mashing methods, they don't work
        # $definitions = { %$definitions, %$tempDefinitions};
        #$definitions->{Tests}->{Test} = { %$definitions->{Tests}->{Test}, %$tempDefinitions->{Tests}->{Test} };
    } 
}

# my $definitions = XMLin($runConfig->{include}, ForceArray => [ 'Define' , 'PostTest' , 'PreTest' ], KeyAttr => [ 'id' , 'loop' ]);

my @products = glob("*product.xml");

# These values are used PER PRODUCT, but are also referenced by the subroutines and I want to keep them factored
# out of the overarching loop, so let's initialize them here and then change their values within each iteration.
my $product;
my %DEFINES = ();
my $OUTPUT;

foreach (@products) {
    print "-i- Generating DVTS script based on: \t$_\n-i-\n";
    my $product = XMLin($_, ForceArray => [], KeyAttr => [ "id" ]);

    # Pure debug section for nailing down which parts of XML become what data structures (hash, hash ref, array, bleh, etc)
    # and for setting up arguments to XMLin above to make access more intuitive...ish.
    # -----------------------------------------------------------------
    # print Dumper($runConfig);
    # print "#################################\n\n";
    # print Dumper($definitions);
    # print "#################################\n\n";
    # print Dumper($product);
    # print "#################################\n\n";

    # -----------------------------------------------------------------

    # Script Pre-work

    # Grab all defines that will be used during DVTS generation and keep them in a single structure for easy access
    # ASSUMPTION: Loops such as [0.5][1.2][0.1] will be packaged using <start><stop><step> tags within 
    # the tag, not as a comma separated list or some other format. All other defines are declared as:
    # <Define id="...">content</Define> and copied 'dumbly'

    %DEFINES = ();

    # Grab any defines from defines xml
    if (exists $definitions->{Defines}->{Define}) {
        for (keys $definitions->{Defines}->{Define}) {
            if (exists $definitions->{Defines}->{Define}->{$_}->{Start}) {
                my $startVal = $definitions->{Defines}->{Define}->{$_}->{Start};
                my $stopVal = $definitions->{Defines}->{Define}->{$_}->{Stop};
                my $stepVal = $definitions->{Defines}->{Define}->{$_}->{Step};

                my $LoopFormatted = "[$startVal][$stopVal][$stepVal]";

                #print "$LoopFormatted\n";
                # $DEFINES{$definitions->{Defines}->{Define}->{$_}} = $LoopFormatted;
                $DEFINES{$_} = $LoopFormatted;
            } else {
                # $DEFINES{$definitions->{Defines}->{Define}->{$_}} = $definitions->{Defines}->{Define}->{$_};
                $DEFINES{$_} = $definitions->{Defines}->{Define}->{$_}->{content};
            }
        }
    }

    # for (keys %DEFINES) {
    #     print "$_: $DEFINES{$_}\n";
    # }

    # Continue process for product xml
    if (exists $product->{Defines}->{Define}) {
        for (keys $product->{Defines}->{Define}) {
            if (exists $product->{Defines}->{Define}->{$_}->{Start}) {
                my $startVal = $product->{Defines}->{Define}->{$_}->{Start};
                my $stopVal = $product->{Defines}->{Define}->{$_}->{Stop};
                my $stepVal = $product->{Defines}->{Define}->{$_}->{Step};

                my $LoopFormatted = "[$startVal][$stopVal][$stepVal]";

                $DEFINES{$_} = $LoopFormatted;
            } else {
                $DEFINES{$_} = $product->{Defines}->{Define}->{$_}->{content};
            }        
        }
    }

    # for (keys %DEFINES) {
    #     print "$_: $DEFINES{$_}\n";
    # }

    # Clean up the defines hash by checking for ':' references and replacing them with the correct values.
    # May as well do this whole process only once instead of each time we try to call on DEFINES
    for (keys %DEFINES) {
        if ($DEFINES{$_} =~ /^:/) {
            my $keyTemp = $DEFINES{$_};
            $keyTemp =~ tr/://d;
            $DEFINES{$_} = $DEFINES{$keyTemp};
        }
    }

    # for (keys %DEFINES) {
    #     print "$_: $DEFINES{$_}\n";
    # }

    # -----------------------------------------------------------------
    # BEGIN ACTUAL DTVS GENERATION

    my $outfile = $_;
    #print "$outfile\n";
    $outfile =~ s/_[pP]roduct.xml//g;
    #print "$outfile\n";
    $outfile = $outfile . ".dvts";
    #print "$outfile\n";
    open $OUTPUT,">",$outfile or die "Cannot create $outfile: $!";

    # -----------------------------------------------------------------
    # PRE-DEFINE ALL TESTS

    print $OUTPUT "##################################################################################################################################
# TEST instance definitions                                                                                                      #
# Definitions of test instance to be used in session flow                                                                        #
##################################################################################################################################
\n";

    # ASSUMPTION: At a bare minimum, all tests have an Enable, Template, Datalog, Cruncher, and Parameters tag.
    # Even if a test is a copy, it still needs these values so we can write the generic function declaration like so:
    #
    # TEST TPSF(iCBkgndTest)[ITUFF][iCBkgndTest] {
    #     copy C_BASE_FLOWS::CONTROLS_X_X_X_BIN_BEG_StartTime;
    # }

    print "-i- Tests defined in this script:\n";

    foreach (keys $definitions->{Tests}->{Test}){
        my $enable = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Enable});
        # my $enable = $definitions->{Tests}->{Test}->{$_}->{Enable};

        # if ($enable =~ /^:/) {
        #     $enable =~ tr/://d;
        #     $enable = $DEFINES{$enable};
        # }

        my $datalog = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Datalog});  
        if (ref $datalog eq ref {}) {
                $datalog = "";
        }

        my $template = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Template});
        if (ref $template eq ref {}) {
                $template = "";
        }
        
        my $cruncher = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Cruncher});
        if (ref $cruncher eq ref {}) {
                $cruncher = "";
        }


        # print "Test ID: \t$_\n";
        # print "Test Template: \t$template\n";
        # print "Cruncher: \t$cruncher\n";
        # print "Datalog: \t$datalog\n";

        # print "Test is enabled?: \t$enable\n\n";
        # print "Parameters are as follows:\n";

        # Only print to DVTS script body if test is ENABLED
        # Assumption. Enable is allcaps ON wherever it's defined. Anything else is a skip
        if ($enable eq "ON") {
            # Begin test write
            print $OUTPUT "TEST $_($template)[$datalog][$cruncher] {\n";

            # Special print case for when the test is simply a copy of an existing test.
            if (exists $definitions->{Tests}->{Test}->{$_}->{copyof}) {
                my $copyTemp = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{copyof});
                print $OUTPUT "\tcopy $copyTemp;\n";

                # my $copyTemp = $definitions->{Tests}->{Test}->{$_}->{copyof};
                # $copyTemp =~ tr/://d;
                # print $OUTPUT "\tcopy $DEFINES{$copyTemp};\n";
            }

            # Print all variables for this test.
            my %Params = %{$definitions->{Tests}->{Test}->{$_}->{Parameters}};
            foreach my $param (keys %Params) {
                #print "$param\n";
                
                # If parameter starts with a colon AND contains a list of comma separated values, do this noise...
                if ($definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param} =~ /^:/ && $definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param} =~ /,/ ){
                    my @listParamTemp = split(',', $definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param});
                    foreach (@listParamTemp) {
                        $_ = defineOrAssign($_);

                        # $_ =~ tr/://d;
                        # $_ = $DEFINES{$_};                    
                    }
                    print $OUTPUT "\t$param = ";
                    print $OUTPUT join( ',', @listParamTemp );
                    print $OUTPUT ";\n";
                } # If parameter starts with a colon AND contains a list of SPACE separated values, do this noise...
                elsif ($definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param} =~ /^:/ && $definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param} =~ /\s/ ){
                    my @listParamTemp = split(' ', $definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param});
                    foreach (@listParamTemp) {
                        $_ = defineOrAssign($_);

                        # $_ =~ tr/://d;
                        # $_ = $DEFINES{$_};                    
                    }
                    print $OUTPUT "\t$param = ";
                    print $OUTPUT join( ' ', @listParamTemp );
                    print $OUTPUT ";\n";
                } # If the parameter begins with a colon and isn't rude like the guy above, substitute in correct value from DEFINES
                # elsif ($definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param} =~ /^:/) {
                #     # my $paramTemp = $definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param};
                #     # $paramTemp =~ tr/://d;
                #     # print $OUTPUT "\t$param = $DEFINES{$paramTemp};\n";

                #     my $paramTemp = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param});
                #     print $OUTPUT "\t$param = $paramTemp;\n";
                # } 
                else {
                    my $paramTemp = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param});
                    print $OUTPUT "\t$param = $paramTemp;\n";
                    # print $OUTPUT "\t$param = $definitions->{Tests}->{Test}->{$_}->{Parameters}->{$param};\n";
                }            
            }

            # Finish writing this test
            print $OUTPUT "}";

            # Tack on any pre-test instances
            if (exists $definitions->{Tests}->{Test}->{$_}->{PreTests}) {
                my @pretests = @{$definitions->{Tests}->{Test}->{$_}->{PreTests}->{PreTest}};
                # print $OUTPUT " [";
                # print $OUTPUT join( ', ', @pretests );
                # print $OUTPUT "]";
                print $OUTPUT " [" . join( ', ', @pretests ) . "]";
            }

            # Tack on any post-test instances
            if (exists $definitions->{Tests}->{Test}->{$_}->{PostTests}) {
                my @posttests = @{$definitions->{Tests}->{Test}->{$_}->{PostTests}->{PostTest}};
                # print $OUTPUT " [";
                # print $OUTPUT join( ', ', @posttests );
                # print $OUTPUT "]";
                print $OUTPUT " [" . join( ', ', @posttests ) . "]";
            }

            print $OUTPUT "\n\n";

            # Debug message to indicate test was printed
            print "-i-\t$_\n";
        }
    }

    # -----------------------------------------------------------------
    # DEFINE THE TEST SESSION

    print $OUTPUT "##################################################################################################################################
# Session definition                                                                                                             #
# Defines how the data collection should be executed                                                                             #
##################################################################################################################################
\n";

    print $OUTPUT "SESSION {\n";

    # Grab expected parameters to define prior to init and unit sections
    for (keys $runConfig->{Session}) {
        # ASSUMPTION: all tags under <Session> that aren't <Init> or <Unit> are session variables to be written
        # into the DVTS script. 
        # These variables may be defined explicitly, referenced from defines using a : prefix, or left blank.
        unless ($_ eq "Init" || $_ eq "Unit") {
            #my $sessionVarTemp = $runConfig->{Session}->{$_};

            # Two special cases: either the value is a reference to something in DEFINES and needs to be grabbed
            # or it's completely undefined (XMLin returns a hash reference for blank XML tags, apparently)
            # if ($sessionVarTemp =~ /^:/) {
            #     $sessionVarTemp =~ tr/://d;
            #     $sessionVarTemp = $DEFINES{$sessionVarTemp};
            # } elsif (ref $sessionVarTemp eq ref {}) {
            #     $sessionVarTemp = "";
            # }

            my $sessionVarTemp = defineOrAssign($runConfig->{Session}->{$_});

            if (ref $sessionVarTemp eq ref {}) {
                $sessionVarTemp = "";
            }

            print $OUTPUT "\t$_ = $sessionVarTemp;\n";
        }
    }

    # my $LogPath = $runConfig->{Session}->{LogPath};
    # my $LoadPlist = $runConfig->{Session}->{LoadPlist};
    # my $Temp = $runConfig->{Session}->{Temp};
    # my $Continuity = $runConfig->{Session}->{Continuity};
    # my $Shops = $runConfig->{Session}->{Shops};

    # print $OUTPUT "SESSION {\n";
    # print $OUTPUT "\tLogPath = $LogPath;\n";
    # print $OUTPUT "\tLoadPlist = $LoadPlist;\n";
    # print $OUTPUT "\tTemp = $Temp;\n";
    # print $OUTPUT "\tContinuity = $Continuity;\n";
    # print $OUTPUT "\tShops = $Shops;\n";


    print "-i- Tests directly executed in this script:\n";

    # -----------------------------------------------------------------
    # INIT

    print $OUTPUT "\n\tINIT {\n";

    # ASSUMPTION: notice that we're assuming the tests within <Run> are declared either as a reference like 
    # ":TPSF", or explicitly as "TPSF". There is no other form of post-processing of what's inside the tags

    #####
    # Handle Init Vars
    ##### 
    print $OUTPUT "\t\t#Initialization Variable Declarations\n";
    if (exists $runConfig->{Session}->{Init}->{InitVars}->{var}) {
        my @initVars = @{$runConfig->{Session}->{Init}->{InitVars}->{var}};
        foreach my $initVar (@initVars) {
            if ($initVar =~ /^:/) {
                $initVar =~ tr/://d;
            }

            my $varType = defineOrAssign($definitions->{InitVar}->{$initVar}->{VarType});
            my $name = defineOrAssign($definitions->{InitVar}->{$initVar}->{Name});
            # my $varType = $definitions->{InitVar}->{$initVar}->{VarType};
            # my $name = $definitions->{InitVar}->{$initVar}->{Name};
            my $collection = defineOrAssign($definitions->{InitVar}->{$initVar}->{Collection});
            # my $collection = $definitions->{InitVar}->{$initVar}->{Collection};
            # if ($collection =~ /^:/) {
            #     $collection =~ tr/://d;
            #     $collection = $DEFINES{$collection};
            # }

            my $value = defineOrAssign($definitions->{InitVar}->{$initVar}->{Values}->{Value});
            # my $value = $definitions->{InitVar}->{$initVar}->{Values}->{Value};

            # Support different formats for different variable types, currently they behave identically so no point...

            # if ($varType eq 'level') {
            # } elsif ($varType eq 'timing') {
            # }

            print $OUTPUT "\t\t$varType.$collection.$name = $value;\n";
                    
        }
        print $OUTPUT "\n";
    }
    #print $OUTPUT "\n";

    #####
    # Handle Init Instances
    #####
    # If there are multiple Tests to run, it'll be returned as an array instead of a hash, handle this case
    print $OUTPUT "\t\t#Initialization Instance Declarations\n";
    if (ref $runConfig->{Session}->{Init}->{Run}->{Test} eq 'ARRAY') {
        my @initTests = @{$runConfig->{Session}->{Init}->{Run}->{Test}};
        #print @initTests;
        for (@initTests) {
            $_ =~ tr/://d;

            # Prevent user from trying to call an undefined test and throw a warning
            unless (exists $definitions->{Tests}->{Test}->{$_}) {
                die "ERROR, REQUESTED TEST $_ NOT DEFINED IN SUPPLIED XML. Please create a <Test id=\"$_\"> entry in your definition XML to resolve this issue\n";
            }

            my $enable = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Enable});
            # my $enable = $definitions->{Tests}->{Test}->{$_}->{Enable};
            # if ($enable =~ /^:/) {
            #     $enable =~ tr/://d;
            #     $enable = $DEFINES{$enable};
            # }

            if ($enable eq "ON") {
                print $OUTPUT "\t\tRUN $_\n";

                print "-i-\t$_\n";
            }
        }
    } else {
        for (keys $runConfig->{Session}->{Init}->{Run}) {
            $_ = $runConfig->{Session}->{Init}->{Run}->{$_};
            $_ =~ tr/://d;

            # Prevent user from trying to call an undefined test and throw a warning
            unless (exists $definitions->{Tests}->{Test}->{$_}) {
                die "ERROR, REQUESTED TEST $_ NOT DEFINED IN SUPPLIED XML. Please create a <Test id=\"$_\"> entry in your definition XML to resolve this issue\n";
            }

            my $enable = defineOrAssign($definitions->{Tests}->{Test}->{$_}->{Enable});
            # my $enable = $definitions->{Tests}->{Test}->{$_}->{Enable};
            # if ($enable =~ /^:/) {
            #     $enable =~ tr/://d;
            #     $enable = $DEFINES{$enable};
            # }

            if ($enable eq "ON") {
                print $OUTPUT "\t\tRUN $_\n";

                print "-i-\t$_\n";
            }
        }    
    }

    print $OUTPUT "\t}\n\n";


    # -----------------------------------------------------------------
    # UNIT SEQUENCE

    print $OUTPUT "\tUNIT {\n";

    # ASSUMPTION: All 'Actions' are contained within the first level of the <Unit> tag. Each <Action> contains
    # a <Single> to define the targeted uservar, and a <Run> to define the function and loops to execute.
    # <Single> contains a single target, and a single value.
    # <Run> contains a single test, either a direct declaration of the test name, or a reference using the : prefix.
    # <Loops> may contain multiple <Loop> elements

    my @actions = @{$runConfig->{Session}->{Unit}->{Action}};

    foreach my $action (@actions) {
        # Special case for TEMPERATURE parameters within the script and not xCMT
        if (exists $action->{temperature}) {
            print $OUTPUT "\t\t# Declaration of Temperature loop\n";

            my $unitTemperature = defineOrAssign($action->{temperature});
            # my $unitTemperature = $action->{temperature};
            # if ($unitTemperature =~ /^:/) {
            #     $unitTemperature =~ tr/://d;
            #     $unitTemperature = $DEFINES{$unitTemperature};
            # }

            print $OUTPUT "\t\ttemperature = $unitTemperature;\n\n";
        }

        # Special case where this action is only for setting up a series of loops prior to / independently of a test
        if (exists $action->{LoopOnly}) {
            print $OUTPUT "\t\t# Declaration of loop outside of a test\n";
            # Go over each loop item and print any and all grouped loops if they exist
            for (@{$action->{LoopOnly}->{Loops}->{Loop}}) {
                # print "$_\n";

                if ($_ =~ /^:/) {
                    $_ =~ tr/://d;
                }

                # print "$_\n";

                # Declare and populate the structure for the current loop, then print to the DVTS script
                my @stack = ();
                $stack[0] = $definitions->{Loops}->{Loop}->{$_}->{LoopType};
                &defineLoop($_, \@stack);
                &printLoop($_, \@stack, 2);

                # print "##############################\n";
                # print "WHAT THE BLOCK LOOKS LIKE?!?!?!??!\n";
                # print @stack;
                # print "\n##############################\n";
            }
            print $OUTPUT "\n";
        }

        # If this action contains a "Flow" item, print in the specific format for calling an instance from another module
        # ie RUN Module::Instance
        if (exists $action->{Run}->{Flow}) {
            my @flows = @{$action->{Run}->{Flow}};

            foreach my $flowItem (@flows) {
                my $flowItem = defineOrAssign($flowItem);

                print $OUTPUT "\t\tRUN $flowItem\n";
            }

            print $OUTPUT "\n";
        }

        # If this action contains tags to run a test, gather test data, check for any loops internal to the test,
        # and print as needed. 
        if (exists $action->{Run}->{Test}) {
            my @tests = @{$action->{Run}->{Test}};

            foreach my $testId (@tests) {
                #print "TEST ID = $testId\n";
                #my $testId = $action->{Run}->{Test};

                # Test ID might need trimming
                if ($testId =~ /^:/) {
                    $testId =~ tr/://d;
                }

                # print "$testId\n";

                # Prevent user from trying to call an undefined test and throw a warning
                unless (exists $definitions->{Tests}->{Test}->{$testId}) {
                    die "ERROR, REQUESTED TEST $testId NOT DEFINED IN SUPPLIED XML. Please create a <Test id=\"$testId\"> entry in your definition XML to resolve this issue\n";
                }

                my $enable = defineOrAssign($definitions->{Tests}->{Test}->{$testId}->{Enable});
                # my $enable = $definitions->{Tests}->{Test}->{$testId}->{Enable};

                # if ($enable =~ /^:/) {
                #     $enable =~ tr/://d;
                #     $enable = $DEFINES{$enable};
                # }

                if ($enable eq "ON") {
                    print $OUTPUT "\t\t# Declarations of test and any internal loops\n";
                    # If there is a loop target...
                    if (exists $action->{Single}->{LoopTarget}) {

                        ###############################################################################################
                        # Define primary target variable for this test/loop combo
                        ###############################################################################################
                        my $Value = defineOrAssign($action->{Single}->{Value});
                        # print "$Value\n";

                        # Access the target loop's details
                        my %targetLoopDefinition = ();

                        # Note for self, loopnames seem to be randomly preceeded by colons, doesn't mean they're a reference tho
                        my $loopId = $action->{Single}->{LoopTarget};
                        if ($loopId =~ /^:/) {
                            $loopId =~ tr/://d;
                        }

                        # Access each element of the target loop definition and define
                        for (keys %{$definitions->{Loops}->{Loop}->{$loopId}}) {
                            $targetLoopDefinition{$_} = defineOrAssign($definitions->{Loops}->{Loop}->{$loopId}->{$_});

                            # # I can do this dereferencing stuff all day
                            # if ($targetLoopDefinition{$_} =~ /^:/) {
                            #     $targetLoopDefinition{$_} =~ tr/://d;
                            #     $targetLoopDefinition{$_} = $DEFINES{$targetLoopDefinition{$_}};
                            # }

                            # print "\t$_ = $targetLoopDefinition{$_}\n";
                        }

                        my $LoopType = defineOrAssign($targetLoopDefinition{LoopType});
                        my $UserVarType = defineOrAssign($targetLoopDefinition{UserVarType});
                        my $Collection = defineOrAssign($targetLoopDefinition{Collection});
                        my $Name = defineOrAssign($targetLoopDefinition{Name});

                        # ASSUMPTION: The only 'targets' seen at the time of writing this script were the generic 'tName'  type.
                        # Each target has a LoopType, UserVarType, Collection, and Name defined. Any other tags within the <Loop>
                        # will be grabbed and defined (refer to the for loop directly above this comment), but since the print 
                        # format is unknown outside of this case, they will not be passed onto the DVTS script in any way.

                        print $OUTPUT "\t\t$LoopType.$UserVarType.$Collection.$Name = $Value;\n";
                    }

                    ###############################################################################################
                    # Now lets write the test to run for the variable defined above
                    ###############################################################################################

                    # Begin print of current test
                    print $OUTPUT "\t\tRUN $testId {\n";

                    # If this test is repeated at all...
                    if (exists $action->{Run}->{Repeat}) {
                        print $OUTPUT "\t\t\tRepeat = $action->{Run}->{Repeat};\n";
                    }

                    # If this tests contains any loops
                    if (exists $action->{Run}->{Loops}->{Loop}) {
                        # Now for loop funtime bonanza...
                        for (@{$action->{Run}->{Loops}->{Loop}}) {
                            #print "$_\n";

                            if ($_ =~ /^:/) {
                                $_ =~ tr/://d;
                            }

                            #print "$_\n";

                            # Declare and populate the structure for the current loop, then print to the DVTS script
                            my @stack = ();
                            $stack[0] = "$_";
                            &defineLoop($_, \@stack);
                            &printLoop($testId, \@stack, 3);

                            # print "##############################\n";
                            # print "WHAT THE BLOCK LOOKS LIKE?!?!?!??!\n";
                            # print @stack;
                            # print "\n##############################\n";
                        }
                    }

                    # End print of current test
                    print $OUTPUT "\t\t}\n\n";

                    print "-i-\t$testId\n";
                }
            }
        }
    }

    # End print of UNIT 
    print $OUTPUT "\t}\n";

    # End print of SESSION
    print $OUTPUT "}\n";

    # Have some sort of debug statement to separate output when there are multiple products
    print "-i- Script generation complete...\n-i-\n";
}




# -----------------------------------------------------------------
# SUBROUTINES

# ASSUMPTIONS:
# -Contents of the <GroupedLoops>'s <Loop> tag is either an explicit loop name or a : reference to another 
# defined loop within the XML. Full definitions of a loop should be their own <Loop id="..."> entries at 
# another point in the XML.
# 
# -Loop definitions contain tags for their respective LoopType as shown in the if/else cases below. 
# All loops contain a <Values>/<Value> tag. Values may be explicit or a reference.
# Currently only <Pattern> and <Value> tags support referencing, all other types are expected to be explicitly declared.

sub defineLoop {
    # Define Columns variable and shift it in to cover the case of grouped loops using defined column values
    my $Columns;
    my $currLoop = shift;
    my $masterStackRef = shift;
    $Columns = shift;

    my $currType = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{LoopType});
    # my $currType = $definitions->{Loops}->{Loop}->{$currLoop}->{LoopType};

    # Base case, we have reached a non-grouped loop. Push contents onto the stack of loops to be printed
    if ($currType ne 'grouped') {
        # print "\t\tThis one isn't grouped\n";

        my $LoopType = $currType;
        my $Values = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Values}->{Value});
        # my $Values = $definitions->{Loops}->{Loop}->{$currLoop}->{Values}->{Value};

        # if ($Values =~ /^:/) {
        #     $Values =~ tr/://d;
        #     $Values = $DEFINES{$Values};
        # }
        
        my $toPush = "";

        if ($currType eq 'uservar') {
            my $Name = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Name});
            my $UserVarType = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{UserVarType});
            my $Collection = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Collection});
            # my $Name = $definitions->{Loops}->{Loop}->{$currLoop}->{Name};
            # my $UserVarType = $definitions->{Loops}->{Loop}->{$currLoop}->{UserVarType};
            # my $Collection = $definitions->{Loops}->{Loop}->{$currLoop}->{Collection};

            # print "-i- userVar = $LoopType.$UserVarType.$Collection.$Name = $Values;\n";
            $toPush = "$LoopType.$UserVarType.$Collection.$Name = $Values";
        } elsif ($currType eq 'level') {
            my $Name = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Name});
            # my $Name = $definitions->{Loops}->{Loop}->{$currLoop}->{Name};

            # print "-i- levelBlock = $LoopType.$Name = $Values;\n";
            $toPush = "$LoopType.$Name = $Values";
        } elsif ($currType eq 'singleLevel') {
            my $Name = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Name});
            $Columns = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Columns});
            # my $Name = $definitions->{Loops}->{Loop}->{$currLoop}->{Name};
            # $Columns = $definitions->{Loops}->{Loop}->{$currLoop}->{Columns};

            my $Collection = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Collection});
            # my $Collection = $definitions->{Loops}->{Loop}->{$currLoop}->{Collection};
            # if ($Collection =~ /^:/) {
            #     $Collection =~ tr/://d;
            #     $Collection = $DEFINES{$Collection};
            # }

            # print "-i- levelBlock = $LoopType.$Name = $Values;\n";
            $toPush = "level.$Collection.$Name = $Values";

            # Change value of "Values" so we can push the column names to the top of the loop declaration
            # Look at me hacking my own script and being sneaky
            #$Values = $Columns;
        } elsif ($currType eq 'singleTiming') {
            my $Name = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Name});
            $Columns = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Columns});
            # my $Name = $definitions->{Loops}->{Loop}->{$currLoop}->{Name};
            # $Columns = $definitions->{Loops}->{Loop}->{$currLoop}->{Columns};

            my $Collection = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Collection});
            # my $Collection = $definitions->{Loops}->{Loop}->{$currLoop}->{Collection};
            # if ($Collection =~ /^:/) {
            #     $Collection =~ tr/://d;
            #     $Collection = $DEFINES{$Collection};
            # }

            # print "-i- levelBlock = $LoopType.$Name = $Values;\n";
            $toPush = "timing.$Collection.$Name = $Values";

            # Change value of "Values" so we can push the column names to the top of the loop declaration
            # Look at me hacking my own script and being sneaky
            #$Values = $Columns;
        } elsif ($currType eq 'patmod') {
            my $Name = defineOrAssign($currLoop);
            # my $Name = $currLoop;
            my $Domain = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Domain});
            # my $Domain = $definitions->{Loops}->{Loop}->{$currLoop}->{Domain};

            my $Start = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Start});
            # my $Start = $definitions->{Loops}->{Loop}->{$currLoop}->{Start};
            # if ($Start =~ /^:/) {
            #     $Start =~ tr/://d;
            #     $Start = $DEFINES{$Start};
            # }

            my $Pin = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Pin});
            my $Offset = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Offset});
            # my $Pin = $definitions->{Loops}->{Loop}->{$currLoop}->{Pin};
            # my $Offset = $definitions->{Loops}->{Loop}->{$currLoop}->{Offset};

            my $Pattern = defineOrAssign($definitions->{Loops}->{Loop}->{$currLoop}->{Pattern});
            # my $Pattern = $definitions->{Loops}->{Loop}->{$currLoop}->{Pattern};
            # if ($Pattern =~ /^:/) {
            #     $Pattern =~ tr/://d;
            #     $Pattern = $DEFINES{$Pattern};
            # }

            $toPush = "$LoopType.$Pattern.$Domain.$Start.$Pin.$Offset.$Name = $Values";
        } # other loop types / cases can go here later on

        # If $Columns is initialized, then we're either dealing with a special single or grouped loop and
        # we need to make sure the $Values in this case is modified so the loop declaration has the column
        # headers instead of the $values used by all loops like in the case of a standard loop
        if (defined $Columns) {
            $Values = $Columns
        }

        @$masterStackRef[1] = $Values;
        #}

        push(@$masterStackRef, $toPush);
    } else { # Recursive case, dig deeper
        # print "\t\tThis one is grouped, recurse\n";

        for (@{$definitions->{Loops}->{Loop}->{$currLoop}->{GroupedLoops}->{Loop}}) {
            if ($_ =~ /^:/) {
                $_ =~ tr/://d;
            }

            # Check here if this is a special grouped loop (like from FIVR) which has special headers
            # for logging to ituff, if yes, pass these along while recursing! Otherwise assume default behavior
            if (exists $definitions->{Loops}->{Loop}->{$currLoop}->{Columns}) {
                # print "\t\t\t\t\tNESTED LEWP: $_\n\n";
                &defineLoop($_, $masterStackRef, $definitions->{Loops}->{Loop}->{$currLoop}->{Columns});
            } else {
                # print "\t\t\t\t\tNESTED LEWP: $_\n\n";
                &defineLoop($_, $masterStackRef);
            }
            
        }
    }

    return;
}

# This really doesn't warrant a comment
sub printLoop {
    my $loopName = shift;
    my $currLoop = shift;
    my $indentationDepth = shift;
    my $type = @$currLoop[0];
    my $values = @$currLoop[1];

    # Logic for handling patmods (apparently not needed)
    # if ($type =~ /patmod/ ) {
    #     my @patmodValues = split(', ', $values);
    #     for (@patmodValues) {
    #         $_ = $_ * 100;
    #         #print "Number: $_\n";
    #     }

    #     $values = join(', ',@patmodValues);
    # }

    # Print outer layer of the loop
    print $OUTPUT ("\t" x $indentationDepth) . "$loopName" . "_" . "$type = $values {\n";

    # Print contents
    for (my $index = 2; $index < @$currLoop; $index++) {
        print $OUTPUT ("\t" x ($indentationDepth + 1) ) . "@$currLoop[$index];\n";
    }

    # End print
    print $OUTPUT ("\t" x $indentationDepth) . "}\n\n";

    return;
}

# I'm tired of this code showing up everywhere, factor it out...
# Basically... if the variable starts with a colon, it's a generic value in DEFINE that is being called,
# otherwise it's defined literally, just pass the value back.
sub defineOrAssign {
    my $result = shift;
    # Temporarily store the original value for error checking
    my $elementID = $result;    

    if ($result =~ /^:/) {
        $result =~ tr/://d;
        $result = $DEFINES{$result};
        #print "$result\n";
        unless (defined $result) {
            die "ERROR, the value you're trying to call is not defined.\n Please verify that the following element is properly defined and any calls\n to it have the proper spelling: $elementID\n";
        }        
    }

    return $result;
}