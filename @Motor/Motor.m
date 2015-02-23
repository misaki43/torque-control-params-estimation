classdef Motor < Joint
    %MOTOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        N_HEAD = 0;
        N_TORSO = 3;
        N_HAND = 5;
        N_LEG = 6;
        ANKLE_START = 4;
        Voltage;
        range_pwm;
        
        q;
        qdot;
        torque;
        pwm;
        voltage;
        current;
        time;
        path_before;
        WBIname;
        ratio_V = 1;
    end
    
    properties (Access = protected)
        start_folder;
        part;
        type;
        info1;
        info2;
        robot_dof = 0;
        measure;
        friction_model;
    end
    
    properties
        robot;
        number;
        number_part;
        path;
        group_select;
        friction;
        select;
        Kt;
    end
    
    methods
        function joint = Motor(start_folder, robot, part, type, info1, info2)
            joint.start_folder = start_folder;
            joint.robot = robot;
            joint.part = part;
            if exist('type','var')
                joint.type = type;
            end
            if exist('info1','var')
                joint.info1 = info1;
            end
            if exist('info2','var')
                joint.info2 = info2;
            end
            joint.robot_dof = 25;
            % TODO remove
            % Build folder
            joint = joint.buildFolder();
        end
        
        function joint = loadIdleMeasureData(joint, position, velocity, acceleration, torque, time, cutoff)
            if exist('cutoff','var')
                joint.friction = Friction(position, velocity, acceleration, torque, time, cutoff);
            else
                joint.friction = Friction(position, velocity, acceleration, torque, time);
            end
        end
        
        function joint = setRatio(joint, Voltage, range_pwm)
            joint.Voltage = Voltage;
            joint.range_pwm = range_pwm;
            joint.ratio_V = Voltage/range_pwm;
        end
        
        function joint = setFrictionToCenter(joint)
            joint.friction = joint.friction.setToCenter();
        end
        
        function joint = loadReference(joint, data)
            joint.q = data.q;
            joint.qdot = data.qD;
            joint.torque = data.tau;
            temp_pwm = data.PWM.(joint.group_select);
            joint.pwm = temp_pwm(:,joint.number_part);
            joint.voltage = joint.ratio_V*joint.pwm;
            if isfield(data,'current')
                joint.current = data.current;
            end
            joint.time = data.time;
            joint.friction_model = joint.friction.getFriction(joint.qdot);
            joint = joint.evaluateCoeff();
        end
        
        function joint = evaluateCoeff(joint)
            A = joint.linearRegression(joint.voltage,joint.torque-joint.friction_model);
            %A = joint.linearRegression(joint.current,joint.torque-joint.friction_model);
            joint.Kt = A(1);
        end
        
        function plotKt(joint, option)
            %% Plot measure versus friction estimation
            if ~exist('option','var')
                option = '.';
            end
            plot(joint.voltage, joint.torque-joint.friction_model, option);
            if joint.ratio_V == 1
                xlabel('PWM','Interpreter','tex');
            else 
                xlabel('Voltage','Interpreter','tex');
            end
            ylabel('\tau-\tau_{f}','Interpreter','tex');
            name = [upper(joint.part) ' ' upper(joint.type) ' ' upper(joint.info1) ' ' upper(joint.info2)];
            title(['Kt: ' joint.Kt ' - motor:' name ]);
            hold on;
            plot(joint.voltage , joint.voltage*joint.Kt,'r-','LineWidth',3);
            hold off;
            %plot(joint.current,joint.current*joint.a(1),'r-','LineWidth',3);
        end
        
        
        function savePictureToFile(joint,hFig,figureName)
            %% Save Friction picture
            % Save image
            currentFolder = pwd;
            cd(joint.path);
            if ~exist('figureName','var')
                figureName = 'friction';
            end
            saveas(hFig,[figureName '.fig'],'fig');
            saveas(hFig,[figureName '.png'],'png');
            cd(currentFolder);
            clear currentFolder;
        end
        
        function text = saveCoeffToFile(joint)
            %% Write information to txt file
            
            % Information joint estimation
            text = sprintf('Name: %s\n',joint.robot);
            text = [text, sprintf('Part: %s\n',joint.part)];
            if(joint.type ~= 0)
                text = [text, sprintf('Type: %s\n',joint.type)];
            end
            if(joint.info1 ~= 0)
                text = [text, sprintf('Info1: %s\n',joint.info1)];
            end
            if(joint.info2 ~= 0)
                text = [text, sprintf('Info2: %s\n',joint.info2)];
            end
            text = [text, sprintf('%s\n',joint.friction.saveToFile(joint.path))];
            
            if size(joint.Kt,1) ~= 0
                
                text = [text, sprintf('\n----------> Kt <----------\n')];
                text = [text, sprintf('tau_m = Kt*PWM \n')];
                text = [text, sprintf('Kt: %12.8f [Nm]/[V]\n',joint.Kt)];
            end
        end
        
        function text = saveLatexCoeffToFile(joint)
            text = sprintf('\n---- Kt -> Latex ----\n');
            
            text = [text, sprintf('\n\\begin{equation}\n')];
            text = [text, sprintf('\\label{eq:%sCoeffPWM}\n',joint.path)];
            text = [text, sprintf('\\begin{array}{cccl}\n')];
            text = [text, sprintf('\\bar Kt & \\simeq & %12.8f & \\frac{[Nm]}{[V]}\n',joint.friction.KvP)];
            text = [text, sprintf('\\end{array}\n')];
            text = [text, sprintf('\\end{equation}\n')];
        end
        
        function text = textControlData(joint)
            % Information joint estimation
            text = sprintf('Name: %s\n',joint.robot);
            text = [text sprintf('Part: %s\n',joint.part)];
            if(joint.type ~= 0)
                text = [text sprintf('Type: %s\n',joint.type)];
            end
            if(joint.info1 ~= 0)
                text = [text sprintf('Info1: %s\n',joint.info1)];
            end
            if(joint.info2 ~= 0)
                text = [text sprintf('Info2: %s\n',joint.info2)];
            end
            text = [text sprintf('\nFriction\n')];
            text = [text sprintf('PWM = kt tau - [s(q)(kc+ + kv+ qdot q) + s(-q)(kc- + kv- qdot q)]\n')];
            text = [text sprintf('kc+: %12.8f [V] - kc-: %12.8f [V] \n',joint.friction.KcP/joint.Kt, joint.friction.KcN/joint.Kt)];
            text = [text sprintf('kv+: %12.8f [V][s]/[deg] - kv-: %12.8f [V][s]/[deg]\n',joint.friction.KvP/joint.Kt, joint.friction.KvN/joint.Kt)];
            %fprintf(fileID,'KsP: %12.8f [Nm] - KsN %12.8f [Nm][s]/[deg]\n',joint.friction.KsP, joint.friction.KsN);
            text = [text sprintf('kt: %12.8f [V]/[Nm]\n',1/joint.Kt)];
        end
        
        function path = getPathType(joint)
            %% Get path type
            path = joint.path_before;
        end
    end
    
    methods (Access = protected)
        function joint = buildFolder(joint)
            %% Build a folder path and if doesn't exist a folder build a
            % selected forlder from information type of joint
            joint = joint.JointStructure(); % Build path
            if ~exist(joint.path,'dir') % Build folder
                mkdir(joint.path);
            end
        end
    end
    
    methods (Access = protected, Static)
        function a = linearRegression(x, y)
            %% Linear regression to evalute coefficent for friction
            % Line equal y = a(1)*x + a(2)
            a = zeros(2,1);
            r = corrcoef(x,y); % Corr coeff is the off-diagonal (1,2) element
            r = r(1,2);  % Sample regression coefficient
            xbar = mean(x);
            ybar = mean(y);
            sigx = std(x);
            sigy = std(y);
            a1 = r*sigy/sigx;   % Regression line slope
            %yfit = ybar - a1*xbar + a1*x;
            a(1) = a1;
            a(2) = ybar - a1*xbar;
        end
        function number = pitchRollYawNumber(info)
            number = 0;
            if strcmp(info,'pitch')
                number = 1;
            elseif strcmp(info,'roll')
                number = 2;
            elseif strcmp(info,'yaw')
                number = 3;
            end
        end
    end
    
end

