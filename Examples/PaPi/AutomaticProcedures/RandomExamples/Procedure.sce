
function [sim, v] = Auto_Experiment_Test1(sim, lam, ang, rlam, gam, pm1, pm2)

    function [sim, finished, outlist, userdata] = ExperimentCntrl(sim, ev, inlist, userdata, CalledOnline)

        // Define parameters. They must be defined once again at this place, because this will also be called at
        // runtime.





        function [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_LambdaRange_AutoCal(sim, States, PacketFramework, par, Flag, InstanceName, lam, ang);
            // This implements a state machine that can be initialised or updated depending on the used Flag
            // It can be used to e.g. perform an experiment+evaluation in form of a sub-procedure that can be used in
            // different parent control system.


            deff('[x]=ra(from,to,len)','x=linspace(from,to,len)'' ');
            deff('[x]=co(val,len)','x=val*ones(1,len)'' ');
            deff('[x]=cosra(from,to,len)','  x=0.5-0.5*cos(linspace(0,%pi,len)); x=x*(to-from)+from; x=x'';  ');
            z = poly(0, 'z');


            ProcedureFinished = %f;
            finished = []; // signal dummy variables
            v = [];

            if Flag == 'update' then

                // Only when this flag is called ORTD-schematics should be build 
                printf("Entering update flag of EC_LambdaFB_AngleTraj %s\n", InstanceName);

                select States.StateMachine.state





                case 'state1'  // e.g. prepare the conroller to drive an experiment
                    [sim, zero] = ld_const(sim, ev, 0);
                    [sim] = ld_printf(sim, 0, zero, "Lambdacontrol active ", 1);



                    // some reference
                    L1 = par.v_NonContractive; L2 = 1;
                    vTestRef = [  co(L1,2*27);      ra(L1,L2,3*27);  ra(L2,L1,1*27)      ];
                    Ann_     = [ co(  1, 2*27);   co(  2, 3*27)  ; co(  3, 1*27)       ];


                    //  make signals form the parameters above
                    [sim, v] = ld_play_simple(sim, 0, vTestRef );
                    [sim, Ann] = ld_play_simple(sim, 0, Ann_ );


                    // Save data
                    [sim, Save] = ld_mux(sim, 0, 4, list( v, lam, ang, Ann ) );
                    [sim] = ld_savefile(sim, 0, fname="AutoResults/EC_LambdaRange_AutoCal.dat", source=Save, vlen=4);

                    //
                    // Stream the data of the oscillator


                    [PacketFramework, PlotXY] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Stimulation intensity", "(500,300)", "(0,0)", "PaPI-Tab", list(["yRange","[-0.1 1.1]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=v, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="v_CntrlByLC", PlotXY, 'SourceGroup0');


                    [PacketFramework, Plot2] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Recruitment", "(500,300)", "(0,300)", "PaPI-Tab", list(["yRange","[-0.1 10.1]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=lam, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="lam", Plot2, 'SourceGroup0');


                    [PacketFramework, Plot2] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Angle", "(500,300)", "(0,600)", "PaPI-Tab", list(["yRange","[-0.1 2]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=ang, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="Th", Plot2, 'SourceGroup0');





                    [sim, finished] = ld_steps2(sim, 0, activation_simsteps=length( vTestRef ), values=[0,1] );


                    States.StateMachine.state = 'state2';
                    ProcedureFinished = %f;

                case 'state2' // e.g. evaluate the results of this experiment
                    // perform the evaiuation of the control experiment defined in 'state1'
                    // and store their results in States.

                    // Let the user verify the results at this place
                    // show an option list to the user
                    par.type = "optionlist";
                    par.options = list("Go on", "Redo");
                    par.size = "(190,150)";
                    par.position = "(600,375)";
                    par.title = "Proceed...";

                    [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, ret] = EC_UIRequest(sim, States=States.EC_UIRequest1, PacketFramework, par, Flag='update', InstanceName=InstanceName+'.EC_UIRequest1');
                    States.EC_UIRequest1 = Nested_States;


                    if Nested_ProcedureFinished == %f then // selection is running
                        err = %f;

                        try    
                            A = fscanfMat("AutoResults/EC_LambdaRange_AutoCal.dat.finished");
                        catch
                            A = fscanfMat("AutoResults/EC_LambdaRange_AutoCal.dat");
                        end

                        v = A(:,1); lambda = A(:,2); angle = A(:,3); Ann=A(:,4);

                        try

                            function [ind] = nearest(vec, n)
                                [m,ind] = min(abs(vec-n));
                            endfunction

                            States.rawData.v = v;
                            States.rawData.lambda = lambda;
                            States.rawData.angle = angle;
                            States.rawData.Ann = Ann;

                            // detect lambda_baseLevel (noise level) 
                            I = find(Ann == 1);
                            States.lambda_baseLevel = mean( lambda( I(2:$) ) ); // skip the first lambda measurement

                            // detect lambdaMax 
                            I = find(Ann == 2 | Ann == 3);
                            States.LambdaMax = max(lambda(I));

                            // detect Angles during stimulation rise 
                            I = find(Ann == 2);

                            I10 = nearest( angle(I), 10/180*%pi );
                            I50 = nearest( angle(I), 30/180*%pi );

                            v__ = v(I);
                            lambda__ = lambda(I);

                            States.v10 = v__(I10);
                            States.v50 = v__(I50);
                            States.lam10 = lambda__(I10);
                            States.lam50 = lambda__(I50);


                            html="";
                            html=html + "v10: " + string(States.v10) + "<br>";
                            html=html + "v50: " + string(States.v50) + "<br>";
                            html=html + "lam10: " + string(States.lam10) + "<br>";
                            html=html + "lam50: " + string(States.lam50) + "<br>";
                            html=html + "lambda_baseLevel: " + string(States.lambda_baseLevel) + "<br>";
                            html=html + "LambdaMax: " + string(States.LambdaMax) + "<br>";


                        catch
                            html = "Error in procedure";
                            err = %t;
                        end


                        // 
                        [sim, zero] = ld_const(sim, ev, 0);
                        v = zero;

                        HTML = "Results<br><br>"+html;
                        [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "HTMLViewer", "Info", "(300,400)", "(500,000)", "PaPI-Tab", list(["content",HTML]));
                    end




                    if Nested_ProcedureFinished then
                        select ret.Selection 
                        case 1 // okay
                            States.StateMachine.state = 'state1';
                            ProcedureFinished = %t; //

                        case 2 // redo
                            States.StateMachine.state = 'state1';     
                            ProcedureFinished = %f; //
                            [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_LambdaRange_AutoCal(sim, States, PacketFramework, par, Flag, InstanceName, lam, ang);
                        end

                    end



                end
            end

            if Flag == 'init' then
                // init states
                clear States;


                [sim, NestedStates, PacketFramework, ProcedureFinished, finished, ret] = EC_UIRequest(sim, States=[], PacketFramework, par=[], Flag='init', InstanceName='EC_UIRequest1');
                States.EC_UIRequest1 = NestedStates;

                // 
                States.StateMachine.state = 'state1'; // initial state of the state machine above

            end

            if Flag == 'destruct' then
                // e.g. to close files or write final results to a file... 
            end
        endfunction











        function [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_LambdaFB_AutoCal(sim, States, PacketFramework, par, Flag, InstanceName, lam, ang);
            // This implements a state machine that can be initialised or updated depending on the used Flag
            // It can be used to e.g. perform an experiment+evaluation in form of a sub-procedure that can be used in
            // different parent control system.


            deff('[x]=ra(from,to,len)','x=linspace(from,to,len)'' ');
            deff('[x]=co(val,len)','x=val*ones(1,len)'' ');
            deff('[x]=cosra(from,to,len)','  x=0.5-0.5*cos(linspace(0,%pi,len)); x=x*(to-from)+from; x=x'';  ');
            z = poly(0, 'z');


            function [sim, u]=controller_I2(sim, ev, r, y, kg)
                // lambda integral controller
                // kg is variable

                z = poly(0, 'z');

                u = r;
                [sim, e] = ld_add(sim, ev, list(r, y), [1, -1] );
                [sim, e_] = ld_mult(sim, ev, list(e, kg), [0,0] ); //

                [sim, u] = ld_limited_integrator2(sim, ev, e_, min__=0.1, max__=1, Ta=1);
            endfunction

            ProcedureFinished = %f;
            finished = []; // signal dummy variables
            v = [];

            if Flag == 'update' then

                // Only when this flag is called ORTD-schematics should be build 
                printf("Entering update flag of EC_LambdaFB_AngleTraj %s\n", InstanceName);

                select States.StateMachine.state

                case 'state1'  // e.g. prepare the conroller to drive an experiment
                    [sim, zero] = ld_const(sim, ev, 0);
                    [sim] = ld_printf(sim, 0, zero, "Lambdacontrol active ", 1);
                    
                    if States.IterationCounter == 1 then
                        States.kg = par.kg_0;
                    end


                    // some reference
                    LamRange = par.LambdaMax - par.lambda_baseLevel;

                    L1 = par.L1; // par.lambda_baseLevel + 0.1 * LamRange;
                    L2 = par.L2; // par.lambda_baseLevel + 0.7 * LamRange;

                    LamTestRef =      [  co(L1,1*27);   co( L2, 1*27);  co(L1, 1*27); co(L2 , 1*27);  co(L1 , 1*27) ];
                    Ann_       =      [  co(0   ,1*27); co(  1, 3*27);                                co(0 , 2*27) ];
                    z = poly(0,'z'); H = (1-0.7)/(z-0.7);

                    // make signals from the parameters above
                    [sim, rlam] = ld_play_simple(sim, 0, LamTestRef );
                    [sim, Ann] = ld_play_simple(sim, 0, Ann_ );

                    //  [sim, rlam] = ld_add_ofs(sim, 0, rlam, par.OnsetPoint_Lam); // add the lambdaref onset


                    // The Lambda Controller
                    [sim, kg] = ld_const(sim, 0, States.kg);
                    [sim, v]=controller_I2(sim, 0, rlam, lam, kg);

                    // Save data
                    [sim, Save] = ld_mux(sim, 0, 5, list( v, lam, rlam, ang, Ann ) );
                    [sim] = ld_savefile(sim, 0, fname="AutoResults/EC_LambdaFB_AutoCal.dat", source=Save, vlen=5);

                    //
                    // Stream the data of the oscillator

                    [PacketFramework, LCD] = ld_PF_addpluginAdvanced(PacketFramework, "LCDDisplay", "kg", "(210,120)", "(500,0)", "PaPI-Tab", list(["updateFrequency","50"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=kg, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="LCDVal", LCD, 'SourceGroup0');


                    [PacketFramework, PlotXY] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Stimulation intensity", "(500,300)", "(0,0)", "PaPI-Tab", list(["yRange","[-0.1 1.1]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=v, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="v_CntrlByLC", PlotXY, 'SourceGroup0');


                    [PacketFramework, Plot2] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Recruitment", "(500,300)", "(0,300)", "PaPI-Tab", list(["yRange","[-0.1 10.1]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=lam, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="lam", Plot2, 'SourceGroup0');
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=rlam, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="rlam", Plot2, 'SourceGroup0');


                    [PacketFramework, Plot2] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Angle", "(500,300)", "(0,600)", "PaPI-Tab", list(["yRange","[-0.1 2]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=ang, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="Th", Plot2, 'SourceGroup0');



                    // Show the results of the iterations so far in a web-window in PaPi
                    Iterations = States.Iterations;

                    HTML = ""; i=1
                    for Iteration = Iterations
                        //    disp(Iteration); // this triggers a segfault (in scilab??)

                        HTML = HTML + "<br>---------- # " + string(i) + "-----------<br>";
                        HTML = HTML + "kg: " + string(Iteration.kg) + "<br>";
                        HTML = HTML + "RMS: " + string(Iteration.RMS) + "<br>";
                        HTML = HTML + "RMSimprovement: " + string(Iteration.RMSimprovement) + "<br>";

                        i=i+1;
                    end
                    //                    disp(HTML);
                    [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "HTMLViewer", "Results", "(300,900)", "(500,120)", "PaPI-Tab", list(["content",HTML]));



                    //                        a.v = [1,2,3,5,9,2,3,4];
                    if States.IterationCounter >= 2 then
                        a.v = States.Iterations($).rawData.lambda;
                        JSONdata = '{ ''v'' :'+ sci2exp(a.v(:)') + '}';

                        // Show a web window, hehe
                        HTML="<html> <head> <script type=''text/javascript'' src=''http://www.user.tu-berlin.de/cklauer/Flotr2/flotr2.min.js''></script> <script type=''text/javascript'' src=''http://code.jquery.com/jquery-1.7.1.min.js''></script> </head> <body> <style type=''text/css''> #Plot { width : 300px; height: 200px; margin: 8px auto; } </style> <div id=''Plot''></div> <br><br> <script> PlotData =' + JSONdata + '; var v = PlotData.v; var data = new Array(v.length); var i, j; for (i=0; i<= v.length; ++i) { data[i] = [ i, v[i] ]; } graph = Flotr.draw(document.getElementById(''Plot''), [ data ], { }); </script> </body> </html>";

                        [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "HTMLViewer", "Results", "(400,400)", "(800,0)", "PaPI-Tab", list(["content",HTML]));
                    end


                    [sim, finished] = ld_steps2(sim, 0, activation_simsteps=length( LamTestRef ), values=[0,1] );


                    States.StateMachine.state = 'state2';
                    ProcedureFinished = %f;

                case 'state2' // e.g. evaluate the results of this experiment
                    // perform the evaiuation of the control experiment defined in 'state1'
                    // and store their results in States.

                    try    
                        A = fscanfMat("AutoResults/EC_LambdaFB_AutoCal.dat.finished");
                    catch
                        A = fscanfMat("AutoResults/EC_LambdaFB_AutoCal.dat");
                    end

                    v = A(:,1); lambda = A(:,2); rlam = A(:,3); angle = A(:,4); Ann=A(:,5);

                    // calc RMS
                    I = find(Ann==1);
                    RMS = sqrt(  sum(( rlam(I)-lambda(I) ).^2) / length(I) );

                    if (States.RMS_jm1 < 0) then
                        // first run
                        States.kg = States.kg + 0.01; // one step to be able to calculate the improvement in the next iteration
                        States.RMS_jm1 = RMS;
                        RMSimprovement = %nan;

                    else

                        RMSimprovement = States.RMS_jm1 - RMS;

                        if (abs(RMSimprovement) > 0.03) then
                            // threre is potentially more room for optimization

                            //
                            States.kg = States.kg + 0.1*(States.RMS_jm1 - RMS); // wenn abl pos. dann ist der RMS besser geworden
                            States.RMS_jm1 = RMS;

                            printf("Optimization: kg=%f, RMS=%f\n", States.kg, RMS);

                        else
                            // iteration finished    
                            ProcedureFinished = %t; // indicates to the parent EC controller that this is finished. The output signals do not have to be valid ORTD-signals in this case.
                        end
                    end


                    // remember the results
                    Iteration.rawData.v = v;
                    Iteration.rawData.lambda = lambda;
                    Iteration.rawData.rlam = rlam;
                    Iteration.rawData.angle = angle;
                    Iteration.rawData.Ann = Ann;
                    Iteration.kg = States.kg;
                    Iteration.RMS = RMS;
                    Iteration.RMSimprovement = RMSimprovement;

                    States.Iterations( States.IterationCounter ) = Iteration;
                    States.IterationCounter = States.IterationCounter + 1;

                    if (ProcedureFinished == %f) then

                        // Do another experiment and iteration
                        States.StateMachine.state = 'state1';

                        // call myself to trigegr this state machine again
                        // to build an ORTD schematic in this place for the next iteration step
                        [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_LambdaFB_AutoCal(sim, States, PacketFramework, par, Flag, InstanceName, lam, ang);

                    else

                        // TODO: Reset states

                    end


                end
            end

            if Flag == 'init' then
                // init states
                clear States;

                // 
                States.StateMachine.state = 'state1'; // initial state of the state machine above
                States.kg = 0.01; // initial gain for the Lambda Controller
                States.RMS_jm1 = -1;
                States.IterationCounter = 1;

                States.Iterations = list();
            end

            if Flag == 'destruct' then
                // e.g. to close files or write final results to a file... 
            end
        endfunction










        function [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_TuneUpperLam(sim, States, PacketFramework, par, Flag, InstanceName, lam, ang)
            // This implements a state machine that can be initialised or updated depending on the used Flag
            // It can be used to e.g. perform an experiment+evaluation in form of a sub-procedure that can be used in
            // different parent control system.

            deff('[x]=ra(from,to,len)','x=linspace(from,to,len)'' ');
            deff('[x]=co(val,len)','x=val*ones(1,len)'' ');
            deff('[x]=cosra(from,to,len)','  x=0.5-0.5*cos(linspace(0,%pi,len)); x=x*(to-from)+from; x=x'';  ');
            z = poly(0, 'z');


            function [sim, u]=controller_I2(sim, ev, r, y, kg)
                // lambda integral controller
                // kg is variable

                z = poly(0, 'z');

                u = r;
                [sim, e] = ld_add(sim, ev, list(r, y), [1, -1] );
                [sim, e_] = ld_mult(sim, ev, list(e, kg), [0,0] ); //

                [sim, u] = ld_limited_integrator2(sim, ev, e_, min__=0.1, max__=1, Ta=1);
            endfunction

            ProcedureFinished = %f;
            finished = []; // signal dummy variables
            v = [];

            if Flag == 'update' then
                // Only when this flag is called ORTD-schematics should be build 
                printf("Entering update flag of EC_TuneUpperLam %s\n", InstanceName);

                select States.StateMachine.state
                case 'state1'  // e.g. prepare the conroller to drive an experiment
                    [sim, zero] = ld_const(sim, ev, 0);
                    [sim] = ld_printf(sim, 0, zero, "EC_TuneUpperLam active ", 1);

                    // Add a button parameter to go to the experiment selection dialog
                    [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "Button", "Leave", "(150,50)", "(600,225)", "PaPI-Tab", list(["state1_text","Done"], ["state2_text","Leaving"]));
                    [sim, PacketFramework, finished]=ld_PF_ParameterInclControl(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="ok", OkButton, 'Click_Event');

                    // A slider shown to the user to adjust rlambda
                    [PacketFramework, Slider] = ld_PF_addpluginAdvanced(PacketFramework, "Slider", "Lambda Ref", "(500,75)", "(500,120)", "PaPI-Tab", list(["step_count","101"], ["lower_bound","0.0"], ["upper_bound", string( par.LambdaMax ) ]));
                    [sim, PacketFramework, rlam]=ld_PF_ParameterInclControl(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="sliderVal", Slider, 'SliderBlock');

                    // The Lambda Controller
                    [sim, kg] = ld_const(sim, 0, par.kg);
                    [sim, v]=controller_I2(sim, 0, rlam, lam, kg);

                    // Add a button parameter to go to the experiment selection dialog
                    [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "Radiobutton", "Annotation", "(190,150)", "(600,375)", "PaPI-Tab", list(["option_texts","None, 10Deg, 50Deg"], ["selected_index","0"], ["option_values", "0,1,2"])); // selected_index = 0,1,2,3...
                    [sim, PacketFramework, AnnSelect]=ld_PF_ParameterInclControl(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="Annotation", OkButton, 'Choice');

                    // Save data
                    [sim, Save] = ld_mux(sim, 0, 5, list( v, lam, rlam, ang, AnnSelect ) );
                    [sim] = ld_savefile(sim, 0, fname="AutoResults/EC_TuneUpperLam_" + InstanceName + ".dat", source=Save, vlen=5);

                    //
                    // Stream the data 
                    [PacketFramework, PlotXY] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Stimulation intensity", "(500,300)", "(0,0)", "PaPI-Tab", list(["yRange","[-0.1 1.1]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=v, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="v_CntrlByLC", PlotXY, 'SourceGroup0');


                    [PacketFramework, Plot2] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Recruitment", "(500,300)", "(0,300)", "PaPI-Tab", list(["yRange","[-0.1 10.1]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=lam, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="lam", Plot2, 'SourceGroup0');
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=rlam, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="rlam", Plot2, 'SourceGroup0');


                    [PacketFramework, Plot2] = ld_PF_addpluginAdvanced(PacketFramework, "Plot", "Angle", "(500,300)", "(0,600)", "PaPI-Tab", list(["yRange","[-0.1 2]"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=ang, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="Th", Plot2, 'SourceGroup0');

                    [sim, angDeg] = ld_gain(sim, 0, ang, 180/%pi);
                    [PacketFramework, LCD] = ld_PF_addpluginAdvanced(PacketFramework, "LCDDisplay", "Joint angle", "(210,120)", "(500,0)", "PaPI-Tab", list(["updateFrequency","20"]));
                    [sim, PacketFramework]=ld_SendPacketInclSub(sim, PacketFramework, Signal=angDeg, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="LCDVal", LCD, 'SourceGroup0');


                    HTML = "Ajust the slider such that a joint angle of approx. 50 degree is achieved.";
                    [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "HTMLViewer", "Info", "(300,250)", "(500,600)", "PaPI-Tab", list(["content",HTML]));



                    States.StateMachine.state = 'state2';
                    ProcedureFinished = %f;

                case 'state2' // e.g. evaluate the results of this experiment
                    // perform the evaiuation of the control experiment defined in 'state1'
                    // and store their results in States.


                    // Let the user verify the results at this place
                    // show an option list to the user
                    par.type = "optionlist"
                    par.options = list("Go on", "Redo");
                    par.size = "(190,150)";
                    par.position = "(600,375)";
                    par.title = "Proceed...";

                    [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, ret] = EC_UIRequest(sim, States=States.EC_UIRequest1, PacketFramework, par, Flag='update', InstanceName=InstanceName+'.EC_UIRequest1');
                    States.EC_UIRequest1 = Nested_States;



                    printf("EC_TuneUpperLam has been finished\n");


                    if Nested_ProcedureFinished == %f then // selection is running

                        err = %f;

                        try    
                            A = fscanfMat("AutoResults/EC_TuneUpperLam_EC_MainControl_1.EC_TuneUpperLam.dat.finished");
                        catch
                            A = fscanfMat("AutoResults/EC_TuneUpperLam_EC_MainControl_1.EC_TuneUpperLam.dat");
                        end


                        v = A(:,1); lambda = A(:,2); rlam = A(:,3); angle = A(:,4); Ann=A(:,5);

                        try
                            
                            States.rawData.v = v;
                            States.rawData.lambda = lambda;
                            States.rawData.rlam = rlam;
                            States.rawData.angle = angle;
                            States.rawData.Ann = Ann;
                            
                            StepI = find(abs(diff(Ann))>0.5);
                            StepToAnn = Ann(StepI+1);

                            // extract data for first annotation (==1)
                            I_=find(StepToAnn == 1);
                            I=StepI(I_($)); // take the last trial
                            I_mean = I:(I+27); // indices for taking the mean values

                            Data.Ann1.v = mean(v(I_mean));
                            Data.Ann1.lam = mean(lambda(I_mean));
                            Data.Ann1.rlam = mean(rlam(I_mean));
                            Data.Ann1.angle = mean(angle(I_mean));


                            // extract data for first annotation (==2)
                            I_=find(StepToAnn == 2);
                            I=StepI(I_($)); // take the last trial
                            I_mean = I:(I+27); // indices for taking the mean values

                            Data.Ann2.v = mean(v(I_mean));
                            Data.Ann2.lam = mean(lambda(I_mean));
                            Data.Ann2.rlam = mean(rlam(I_mean));
                            Data.Ann2.angle = mean(angle(I_mean));

                            // build html
                            html="";

                            html=html+"<b>10 deg</b><br>";
                            s=string(Data.Ann1);
                            for i=1:length(length(s))
                                html=html+ s(i) + "<br>";
                            end

                            html=html+"<b>50 deg</b><br>";
                            s=string(Data.Ann2);
                            for i=1:length(length(s))
                                html=html+ s(i) + "<br>";
                            end



                        catch
                            html = "Error in procedure";
                            err = %t;
                        end

                        HTML = "Results<br><br>"+html;
                        [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "HTMLViewer", "Info", "(300,400)", "(500,000)", "PaPI-Tab", list(["content",HTML]));



                        if err == %f then

                            // TODO....
                            States.Stim_Lower = Data.Ann1.v;
                            States.Stim_Upper = Data.Ann2.v;
                            States.Lam_Lower = Data.Ann1.lam;
                            States.Lam_Upper = Data.Ann2.lam;
                            States.Ang_Lower = Data.Ann1.angle;
                            States.Ang_Upper = Data.Ann2.angle;

                        end

                        States.StateMachine.state = 'state2';


                        [sim, zero] = ld_const(sim, ev, 0);
                        v = zero;

                    end





                    if Nested_ProcedureFinished then
                        select ret.Selection 
                        case 1 // okay
                            States.StateMachine.state = 'state1';
                            ProcedureFinished = %t; //

                        case 2 // redo
                            States.StateMachine.state = 'state1';     
                            ProcedureFinished = %f; //                   
                            [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_TuneUpperLam(sim, States, PacketFramework, par, Flag='update', InstanceName, lam, ang);
                        end

                    end



                end
            end

            if Flag == 'init' then
                // init states
                clear States;

                [sim, NestedStates, PacketFramework, ProcedureFinished, finished, ret] = EC_UIRequest(sim, States=[], PacketFramework, par=[], Flag='init', InstanceName='EC_UIRequest1');
                States.EC_UIRequest1 = NestedStates;

                // 
                States.StateMachine.state = 'state1'; // initial state of the state machine above
            end

            if Flag == 'destruct' then
                // e.g. to close files or write final results to a file... 
            end
        endfunction

















        function [sim, States, PacketFramework, ProcedureFinished, finished, ret] = EC_UIRequest(sim, States, PacketFramework, par, Flag, InstanceName);
            // This implements a state machine that can be initialised or updated depending on the used Flag
            // It can be used to e.g. perform an experiment+evaluation in form of a sub-procedure that can be used in
            // different parent control system.

            // par.title, par.options, par.type = "optionlist", par.size, par.position

            z = poly(0, 'z');

            ProcedureFinished = %f;
            finished = []; // signal dummy variables
            ret = [];


            if Flag == 'update' then


                // Only when this flag is called ORTD-schematics should be build 
                //                printf("Entering update flag of EC_LambdaFB_AngleTraj %s\n", InstanceName);

                select States.StateMachine.state

                case 'state1'  // e.g. prepare the conroller to drive an experiment
                    [sim, zero] = ld_const(sim, ev, 0);

                    if par.type == "button" then
                        // TODO

                        //                        // Add a button parameter to go to the experiment selection dialog
                        //                        [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "Button", "Leave", "(150,50)", "(600,225)", "PaPI-Tab", list(["state1_text","Ok"], ["state2_text","Leaving"]));
                        //                        [sim, PacketFramework, GoToChoose]=ld_PF_ParameterInclControl(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="ok", OkButton, 'Click_Event');
                        //                        
                    end

                    if par.type == "optionlist" then
                        par.options;


                        option_texts = ""; option_values = "";
                        for i = 1:(length(par.options)-1)
                            option_texts = option_texts + par.options(i) + ",";
                            option_values = option_values + string(i)+",";
                        end
                        option_texts = option_texts + par.options(length(par.options));
                        option_values = option_values + string(length(par.options));

                        // Add a button parameter to go to the experiment selection dialog
                        [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "Radiobutton", par.title, par.size, par.position, "PaPI-Tab", list(["option_texts", option_texts], ["selected_index",""], ["option_values", option_values])); // selected_index = 0,1,2,3...
                        [sim, PacketFramework, GoToChoose]=ld_PF_ParameterInclControl(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="EC_UIRequest_"+InstanceName, OkButton, 'Choice');


                    end


                    // Save data the value of GoToChoose in the simulation step wherin in GoToChoose becomes greater 0
                    // indicating the user selected something.
                    [sim, SelectionOccured] = ld_detect_step_event(sim, 0, in=GoToChoose, eps=0.5);                    
                    [sim, StopSavingTrigger] = ld_const(sim, 0, 1);
                    [sim, TriggerSave] = ld_cond_overwrite(sim, 0, StopSavingTrigger, condition=SelectionOccured, setto=2); // start saving

                    SaveSignals=list(GoToChoose); FileNamesList=list( "AutoResults/EC_UISelect" + InstanceName + ".dat" );
                    [sim] = ld_file_save_machine2(sim, 0, inlist=SaveSignals, cntrl=TriggerSave, FileNamesList);

                    [sim, finished] = ld_delay(sim, 0, SelectionOccured, N=1); // run this for one more step to allow passing of TriggerSave=2 to ld_file_save_machine2...

                    States.StateMachine.state = 'state2';
                    ProcedureFinished = %f;

                case 'state2' // e.g. evaluate the results of this experiment
                    // perform the evaiuation of the control experiment defined in 'state1'
                    // and store their results in States.

                    sleep(100); // NOTE: ugly workaround:  To ensure the file is closed. Will be fixed by upcoming versions of ORTD

                    try    
                        A = fscanfMat("AutoResults/EC_UISelect" + InstanceName + ".dat.finished");
                    catch
                        A = fscanfMat("AutoResults/EC_UISelect" + InstanceName + ".dat");
                    end

                    Selection = A(:,1); 

                    States.Selection = Selection($);

                    ret.Selection = States.Selection;
                    printf("EC_UISelect" + InstanceName + ": selected was %d\n", States.Selection);

                    // iteration finished    
                    States.StateMachine.state = 'state1'; // initial state of the state machine above
                    ProcedureFinished = %t; // indicates to the parent EC controller that this is finished. The output signals do not have to be valid ORTD-signals in this case.
                end
            end

            if Flag == 'init' then
                // init states
                clear States;

                // 
                States.StateMachine.state = 'state1'; // initial state of the state machine above

            end

            if Flag == 'destruct' then
                // e.g. to close files or write final results to a file... 
            end
        endfunction










        //
        //
        //  The Main Experiment Controller
        //
        //
        //
        //
        //

        function [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_MainControl (sim, States, PacketFramework, par, Flag, InstanceName, lam, gam, ang);

            // This implements a state machine that can be initialised or updated depending on the used Flag
            ProcedureFinished = %f;
            finished = []; // signal dummy variables
            v = [];

            if Flag == 'update' then
                // Only when this flag is called ORTD-schematics should be build 
                printf("Entering update flag of EC %s\n", InstanceName);
                printf("The current state is " + States.StateMachine.state);
                //                disp(States);

                States.counter = States.counter + 1;

                [sim, zero] = ld_const(sim, ev, 0);

                select States.StateMachine.state
                case 'pause'
                    printf("Pause controller is beeing prepared; Counter = %d\n", States.counter);

                    //                    [sim] = ld_printf(sim, 0, zero, "Pause ", 1);
                    [sim, finished] = ld_steps2(sim, 0, activation_simsteps=2-1, values=[0,1] );
                    v = zero;

                    States.StateMachine.state = 'MainMenu'; 
                    [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_MainControl (sim, States, PacketFramework, par, Flag='update', InstanceName, lam, gam, ang);




                case 'MainMenu'

                    // show an option list to the user
                    par.type = "optionlist"
                    par.options = list("Go on", "Calibrate Lambda Min/Max Ranges", "EC_TuneUpperLam", "LC gain calibration");
                    // Experiment_LambdaRange_AutoCal, EC_TuneUpperLam, Experiment_LambdaFB_AutoCal, EC_Stimulation_IdentAngle, EC_LambdaFB_IdentAngle, Experiment1

                    par.size = "(300,400)";
                    par.position = "(620,10)";
                    par.title = "Proceed...";

                    [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, ret] = EC_UIRequest(sim, States=States.EC_UIRequest1.States, PacketFramework, par, Flag='update', InstanceName=InstanceName+'.EC_UIRequest1');
                    States.EC_UIRequest1.States = Nested_States;




                    // actuation var is zero during user selection
                    v = zero;

                    if Nested_ProcedureFinished == %f then
                        // if this is active, the EC_Template has build a schematic for
                        // controlling something

                        // Show a web window
                        HTML="<html><b>Main Screen</b></html>";

                        //HTML = "<html><head><meta http-equiv=''refresh'' content=''0; URL=http://www.google.de''></head></html>";
                        [PacketFramework, OkButton] = ld_PF_addpluginAdvanced(PacketFramework, "HTMLViewer", "Info", "(500,600)", "(10,10)", "PaPI-Tab", list(["content",HTML]));



                        [sim] = ld_printf(sim, 0, zero, "EC_UISelect is running ", 1);
                    end

                    if Nested_ProcedureFinished == %t then
                        // in this case, EC_Template did not build any schematc, because its internal procedure 
                        // has been finished. It is up to this part to build controllers.

                        // next state is deping on user's choice...
                        // Experiment_LambdaRange_AutoCal, EC_TuneUpperLam, Experiment_LambdaFB_AutoCal, EC_Stimulation_IdentAngle, EC_LambdaFB_IdentAngle, Experiment1

                        select ret.Selection 
                        case 1
                            States.StateMachine.state = 'Experiment_LambdaRange_AutoCal'; // the default procedure
                        case 2
                            States.StateMachine.state = 'Experiment_LambdaRange_AutoCal';
                        case 3
                            States.StateMachine.state = 'EC_TuneUpperLam';
                        case 4
                            States.StateMachine.state = 'Experiment_LambdaFB_AutoCal';
                        end
                        printf("Main Menu Selection: %s", States.StateMachine.state);


                        // directly go on with the next state
                        [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_MainControl (sim, States, PacketFramework, par, Flag='update', InstanceName, lam, gam, ang);
                    end






                case 'Experiment_LambdaRange_AutoCal'
                    printf("LambdaRange_AutoCal controller is beeing prepared; Counter = %d\n", States.counter);
                    LogString = 'LambdaRange_AutoCal is beeing prepared';

                    //
                    // An example to include a sub-Experiment Controller
                    // in form of a sub-module provided by the
                    // function EC_Template. When the herein
                    // defined procedure has finished, 
                    // Nested_ProcedureFinished == %t is returned.
                    //

                    // dummy pars
                    z = poly(0,'z');
//                    par.EC_LambdaFB_AutoCal.v = 0.01;  // TODO Prob not necessary
                    par.EC_LambdaFB_AutoCal.v_NonContractive = 0.05; // stimulation int just to trigger pulses that do not contract the muscle


                    [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, v] = EC_LambdaRange_AutoCal(sim, States=States.EC_LambdaRange_AutoCal.States, PacketFramework, par=par.EC_LambdaFB_AutoCal, Flag='update', InstanceName=InstanceName+'.EC_LambdaRange_AutoCal', lam, ang);
                    States.EC_LambdaRange_AutoCal.States = Nested_States;

                    if Nested_ProcedureFinished == %f then
                        // if this is active, the EC_Template has build a schematic for
                        // controlling something
                        [sim] = ld_printf(sim, 0, zero, "LambdaRange_AutoCal is running ", 1);
                    end

                    if Nested_ProcedureFinished == %t then
                        // in this case, EC_Template did not build any schematc, because its internal procedure 
                        // has been finished. It is up to this part to build controllers.
                        mfprintf(States.LogFile_fd, LogString +  "\n");

                        [sim] = ld_printf(sim, 0, zero, "LambdaRange_AutoCal has been finished ", 1);

                        //
                        // Define e.g. some control systems that use the results of the
                        // procedure provided by EC_Template here.
                        //

                        v = zero;
                        [sim, finished] = ld_steps2(sim, 0, activation_simsteps=20-1, values=[0,1] );

                        States.StateMachine.state = 'Experiment_LambdaFB_AutoCal';
                    end


                    ProcedureFinished = %f;  // if %t this state machine is not updated any more.







                case 'Experiment_LambdaFB_AutoCal'
                    printf("Experiment 0 controller is beeing prepared; Counter = %d\n", States.counter);
                    LogString = 'Experiment 0 is beeing prepared';

                    //
                    // An example to include a sub-Experiment Controller
                    // in form of a sub-module provided by the
                    // function EC_Template. When the herein
                    // defined procedure has finished, 
                    // Nested_ProcedureFinished == %t is returned.
                    //

                    // dummy pars
                    z = poly(0,'z');
                    par.EC_LambdaFB_AutoCal.v = 0.01;

//

                    // Copy some results during the previous calibration step to the parameters
                    par.EC_LambdaFB_AutoCal.lambda_baseLevel = States.EC_LambdaRange_AutoCal.States.lambda_baseLevel;
                    par.EC_LambdaFB_AutoCal.LambdaMax = States.EC_LambdaRange_AutoCal.States.LambdaMax;
                    par.EC_LambdaFB_AutoCal.L1 = States.EC_LambdaRange_AutoCal.States.lam10;
                    par.EC_LambdaFB_AutoCal.L2 = States.EC_LambdaRange_AutoCal.States.lam50;
                    par.EC_LambdaFB_AutoCal.kg_0 = 0.01;
                    
                    
                    
                    [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, v] = EC_LambdaFB_AutoCal(sim, States=States.EC_LambdaFB_AutoCal.States, PacketFramework, par=par.EC_LambdaFB_AutoCal, Flag='update', InstanceName=InstanceName+'.EC_LambdaFB_AutoCal', lam, ang);
                    States.EC_LambdaFB_AutoCal.States = Nested_States;

                    if Nested_ProcedureFinished == %f then
                        // if this is active, the EC_Template has build a schematic for
                        // controlling something
                        [sim] = ld_printf(sim, 0, zero, "Experiment_LambdaFB_AutoCal is running ", 1);
                    end

                    if Nested_ProcedureFinished == %t then
                        // in this case, EC_Template did not build any schematc, because its internal procedure 
                        // has been finished. It is up to this part to build controllers.
                        mfprintf(States.LogFile_fd, LogString +  "\n");

                        [sim] = ld_printf(sim, 0, zero, "Experiment_LambdaFB_AutoCal has been finished ", 1);

                        //
                        // Define e.g. some control systems that use the results of the
                        // procedure provided by EC_Template here.
                        //

                        v = zero;
                        [sim, finished] = ld_steps2(sim, 0, activation_simsteps=20-1, values=[0,1] ); // WAIT MORE OR LESS FOREVER

                        States.StateMachine.state = 'EC_TuneUpperLam';
                    end

                    // Stream data
                    [sim, PacketFramework]=ld_SendPacket(sim, PacketFramework, Signal=v, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="v");

                    ProcedureFinished = %f;











                    //EC_TuneUpperLam

                case 'EC_TuneUpperLam'
                    printf("EC_TuneUpperLam controller is beeing prepared; Counter = %d\n", States.counter);
                    LogString = 'EC_TuneUpperLam is beeing prepared';

                    //
                    // An example to include a sub-Experiment Controller
                    // in form of a sub-module provided by the
                    // function EC_Template. When the herein
                    // defined procedure has finished, 
                    // Nested_ProcedureFinished == %t is returned.
                    //

                    // dummy pars
                    z = poly(0,'z');
                    par.EC_TuneUpperLaml.v_NonContractive = 0.05; // stimulation int just to trigger pulses that do not contract the muscle
                    par.EC_TuneUpperLaml.kg = States.EC_LambdaFB_AutoCal.States.kg;
                    par.EC_TuneUpperLaml.LambdaMax = States.EC_LambdaRange_AutoCal.States.LambdaMax;
                    par.EC_TuneUpperLaml.lambda_baseLevel = States.EC_LambdaRange_AutoCal.States.lambda_baseLevel;


                    [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, v] = EC_TuneUpperLam(sim, States=States.EC_TuneUpperLam1.States, PacketFramework, par=par.EC_TuneUpperLaml, Flag='update', InstanceName=InstanceName+'.EC_TuneUpperLam', lam, ang);
                    States.EC_TuneUpperLam1.States = Nested_States;

                    if Nested_ProcedureFinished == %f then
                        // if this is active, the EC_Template has build a schematic for
                        // controlling something
                        [sim] = ld_printf(sim, 0, zero, "EC_TuneUpperLam is running ", 1);
                    end

                    if Nested_ProcedureFinished == %t then
                        // in this case, EC_Template did not build any schematc, because its internal procedure 
                        // has been finished. It is up to this part to build controllers.
                        mfprintf(States.LogFile_fd, LogString +  "\n");

                        [sim] = ld_printf(sim, 0, zero, "EC_TuneUpperLam has been finished ", 1);

                        //
                        // Define e.g. some control systems that use the results of the
                        // procedure provided by EC_Template here.
                        //

                        v = zero;
                        [sim, finished] = ld_steps2(sim, 0, activation_simsteps=20-1, values=[0,1] );

                        States.StateMachine.state = 'EC_Stimulation_IdentAngle';
                    end


                    ProcedureFinished = %f;  // if %t this state machine is not updated any more.






                end


                printf("Next time the state will be " + States.StateMachine.state);

            end

            if Flag == 'init' then
                // init states
                clear States;

                // 
                States.StateMachine.state = 'pause'; // initial state of the state machine above
                States.counter = 1;

                // Open a log file
                States.LogFile_fd = mopen('AutoResults/LogFile.txt','wt');

                // init sub EC's
                [sim, Nested_States, PacketFramework, Nested_ProcedureFinished, finished, ret] = EC_UIRequest(sim, States=[], PacketFramework, par=[], Flag='init', InstanceName=InstanceName+'.EC_UIRequest1');
                States.EC_UIRequest1.States = Nested_States;

                [sim, Nested_States, PacketFramework, ProcedureFinished, finished, v] = EC_LambdaRange_AutoCal(sim, States=[], PacketFramework=[], par=[], Flag='init', InstanceName=InstanceName+'.EC_LambdaRange_AutoCal', lam=[], ang=[]);
                States.EC_LambdaRange_AutoCal.States = Nested_States;

                [sim, Nested_States, PacketFramework, ProcedureFinished, finished, v] = EC_LambdaFB_AutoCal(sim, States=[], PacketFramework=[], par=[], Flag='init', InstanceName=InstanceName+'.EC_LambdaFB_AutoCal', lam=[], ang=[]);
                States.EC_LambdaFB_AutoCal.States = Nested_States;

                [sim, Nested_States, PacketFramework, ProcedureFinished, finished, v] = EC_TuneUpperLam(sim, States=[], PacketFramework=[], par=[], Flag='init', InstanceName=InstanceName+'.EC_TuneUpperLam1', lam=[], ang=[]);
                States.EC_TuneUpperLam1.States = Nested_States;

            end

            if Flag == 'destruct' then
                // e.g. to close files or write final results to a file... 
            end
        endfunction



        if CalledOnline == %t then
            // The contents of this part will be compiled on-line, while the control
            // system is running. The aim is to generate a new compiled schematic for
            // the experiment.
            // Please note: Since this code is only executed on-line, most potential errors 
            // occuring in this part become only visible during runtime.

            printf("Compiling a new control system\n");
            funcprot(0);

            // Load the parameters
            par.EC_MainControl.par.Dummy = 0;


            if userdata.isInitialised == %f then
                userdata.isInitialised = %t; // prevent from initialising the variables once again

                //
                // State variables can be initialise at this place
                //

                USE_RESULTS_FROM_FILE = %f;

                if USE_RESULTS_FROM_FILE==%f then

                    // init the main EC (Experiment Controller)
                    [sim, NestedStates, PacketFramework, ProcedureFinished, finished, v] = EC_MainControl (sim, States=[], PacketFramework=[], par=par.EC_MainControl.par, Flag='init', InstanceName='EC_MainControl_1', lam=[], gam=[], ang=[]);
                    userdata.EC_MainControl.States = NestedStates;

                else
                    // Load the States obtained from a previous execution of the ORTD-programm
                    load('AutoResults/Procedure_states.dat');
                    userdata.EC_MainControl.States = States;
                    clear States;

                    // Directly jump to something to e.g. skip something
                    userdata.EC_MainControl.States.StateMachine.state = 'EC_Stimulation_IdentAngle';


                end
                userdata.EC_MainControl.ProcedureFinished = %f;

            end

            // 
            // Define a new experiment controller schematic depending on the currently active state
            // 

            [sim, zero] = ld_const(sim, ev, 0);
            [sim, one] = ld_const(sim, 0, 1);

            // inputs
            lam = inlist(1);
            gam = inlist(2);
            rlam = inlist(3);
            pm1 = inlist(4);
            pm2 = inlist(5);
            ang = inlist(6);

            // default output (dummy)
            outlist=list(zero, zero, zero, zero, zero, zero);

            // PAPI
            Configuration.UnderlyingProtocoll = "UDP";
            Configuration.DestHost = "127.0.0.1";
//            Configuration.DestHost = "130.149.155.75";            
            Configuration.DestPort = 20000;
            Configuration.LocalSocketHost = "127.0.0.1";
            Configuration.LocalSocketPort = 20001;
            
//            load('PapiCfg.dat');
            [sim, PacketFramework] = ld_PF_InitInstance(sim, InstanceName="PaPi__", Configuration);

            //
            // Here a state-machine is implemented that may be used to implement some automation
            // logic that is executed during runtime using the embedded Scilab interpreter.
            // In this example, a calibration run succeeded by the design/compilation/execution 
            // of a control-system is implemented. The schematics defined in each state are loaded
            // at runtime.
            // 

            if userdata.EC_MainControl.ProcedureFinished == %f then
                // update the main EC
                [sim, States, PacketFramework, ProcedureFinished, finished, v] = EC_MainControl (sim, States=userdata.EC_MainControl.States, PacketFramework, par=par.EC_MainControl.par, Flag='update', InstanceName='EC_MainControl_1', lam, gam, ang);
                userdata.EC_MainControl.States = States;
                userdata.EC_MainControl.ProcedureFinished = ProcedureFinished;
            end

            if userdata.EC_MainControl.ProcedureFinished == %t then
                // EC_MainControl indicated that it has been finished its procedure.
                // Now put default values to the outputs

                v = zero;
                finished = zero; // this schemetic will never finish
            end

            // Save the State-variables that contain e.g. identification results, raw measured data, ....
            save('AutoResults/Procedure_states.dat', 'States');

            // 
            outlist=list(v, zero, zero, zero, zero, zero);


            // PAPI: finalise the communication interface
            [sim,PacketFramework] = ld_PF_Finalise(sim,PacketFramework);
            //                        ld_PF_Export_js(PacketFramework, fname="ProtocollConfig.json");

        end // CalledOnline == %t

        // When RTmain.sce is executed, this part will be run. It may be used to define an initial experiment in advance to
        // the execution of the whole control system.
        if CalledOnline == %f then
            SchematicInfo = "Off-line compiled";

            // default output (dummy)
            [sim, zero] = ld_const(sim, 0, 0);
            outlist=list(zero, zero, zero, zero, zero, zero);
            [sim, finished] = ld_steps2(sim, 0, activation_simsteps=10, values=[0,1] );
        end

    endfunction




    function [sim, outlist, HoldState, userdata] = whileComputing_example(sim, ev, inlist, CalibrationReturnVal, computation_finished, par);

        [sim, HoldState] = ld_const(sim, 0, 0);

        [sim] = ld_printf(sim, 0, HoldState, "calculating ... " , 1);

        // While the computation is running this is called regularly
        [sim, zero] = ld_const(sim, ev, 0);
        outlist=list(zero, zero, zero, zero, zero, zero);
    endfunction


    function [sim, ToScilab, userdata] = PreScilabRun(sim, ev, par)
        userdata = par.userdata;

        [sim, ToScilab] = ld_constvec(sim, 0, [1,2,3,4,5,6,7,8,9,10]);
    endfunction




    // Start the experiment
    ThreadPrioStruct.prio1=ORTD.ORTD_RT_NORMALTASK;
    ThreadPrioStruct.prio2=0, ThreadPrioStruct.cpu = -1;

    insizes=[1,1,1,1,1,1]; outsizes=[1,1,1, 1,1,1];
    intypes=[ORTD.DATATYPE_FLOAT, ORTD.DATATYPE_FLOAT, ORTD.DATATYPE_FLOAT, ORTD.DATATYPE_FLOAT, ORTD.DATATYPE_FLOAT, ORTD.DATATYPE_FLOAT]; 
    outtypes=[ORTD.DATATYPE_FLOAT*ones(6,1)];


    CallbackFns.experiment = ExperimentCntrl;
    CallbackFns.whileComputing = whileComputing_example;
    CallbackFns.PreScilabRun = PreScilabRun;

    // Please note ident_str must be unique.
    userdata = [];
    [sim, finished, outlist, userdata] = ld_AutoOnlineExch_dev(sim, 0, inlist=list(lam, gam, rlam, pm1, pm2, ang), ...
    insizes, outsizes, intypes, outtypes, ... 
    ThreadPrioStruct, CallbackFns, ident_str="Auto_Experiment_Test1", userdata);


    v = outlist(1);
    unused1 = outlist(2); 
    unused2 = outlist(3); 
    rlam = outlist(4); 
    modus = outlist(5);
    Annotation = outlist(6);


    // Save data
    [sim, Save] = ld_mux(sim, 0, 8, list( v, unused1, unused2, lam, rlam, modus, ang, Annotation ) );
    [sim] = ld_savefile(sim, 0, fname="AutoResults/ContinousData.dat", source=Save, vlen=8);

endfunction



