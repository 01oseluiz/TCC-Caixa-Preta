% Ler da porta serial
% Ainda precisa melhorar
% BUGS:
% - file_simulated_freq ainda n�o funciona muito bem

addpath('quaternion_library');      % include quaternion library
addpath('helpers');                 % include some useful functions
close all;                          % close all figures
clear;                              % clear all variables
clc;                                % clear the command terminal

% layout Macros
Vazio = '';                                 % Deixa a celula vazia
Acel = 'A';                                 % Acelera��o x,y,z
Vel = 'B';                                  % Velocidade x,y,z
Space = 'C';                                % Espa�o percorrido x,y,z
Gvel = 'D';                                 % Velocidade angular em x,y,z
Gdeg = 'E';                                 % Posi��o angular em x,y,z relativo (em rela��o a posi��o anterior)
Gtilt = 'F';                                % Posi��o angular em x,y,z absoluto (em rela��o aos eixos iniciais)
Mag = 'G';                                  % Magnetometro
FusionTilt = 'H';                           % Posi��o angular em x,y,z absoluto, usando acelera��o e magnetometro
CompTilt = 'I';                             % Posi��o angular usando o filtro complementar
KalmanTilt = 'J';                           % Posi��o angular usando o filtro de kalman
MadgwickTilt = 'K';                         % Posi��o angular usando o filtro de madgwick
Space3D = 'L';                              % Posi��o em um espa�o 3D
Tilt3D = 'M';                               % Posi��o angular atual usando um objeto 3D
Acel_G = 'N';                               % Acelera��o desconsiderando a gravidade (utilizando o melhor filtro p/ remove-la,
                                            % pois � necess�rio saber bem a posi��o angular p/ isso)


%% PARAMETROS DE USU�RIO %%
% Fonte de leitura
read_from_serial=false;     % Set to false to use a file
serial_COM='COM4';          
serial_baudrate=115200;     
file_full_path='Dados/roll-pitch-roll-90-seq.txt';          
file_simulated_freq=Inf;    % Simulate a pulling frequence, e.g.: to simulate an freq of 100 samples per second use 100hz

% Amostragem
max_size=4000;              % Quantidade maxima de amostras exibidas na tela
freq_sample=100;            % Frequencia da amostragem dos dados

% Plotagem
plot_in_real_time=false;    % Define se o plot ser� so no final, ou em tempo real
freq_render=5;              % Frequencia de atualiza��o do plot
layout= {...                % Layout dos plots, as visualiza��es poss�veis est�o variaveis no inicio do arquivo
    
        Acel,       Acel_G,     FusionTilt,     FusionTilt;...
        Gvel,       Gdeg,       CompTilt,       CompTilt;...
        Gtilt,      Gtilt,      KalmanTilt,     KalmanTilt;...
        Vazio,      Vazio,      MadgwickTilt,   MadgwickTilt;...
        
};                          % OBS: Repita o nome no layout p/ expandir o plot em varios grids

% Constantes do sensor
const_g=9.8;                % Constante gravitacional segundo fabricante do MPU
gx_bias=0.895;                % 
gy_bias=0.91;                % 
gz_bias=0.67;                % 
ax_bias=0.035;                % 
ay_bias=0.04;                % 
az_bias=0.078;              % 
esc_ac=2;                   % Vem do Arduino, fun��o que configura escalas de acelera��o
esc_giro=250;               % e giro //+/- 2g e +/-250gr/seg


% Media movel parametros 
window_k = 10;              % Janela da media movel (minimo = 2)

% Vari�vel de ajuste do filtro complementar
mu=0.02;

% Vari�vel de ajuste do filtro de kalman, os valores iniciais de X e P s�o por padr�o 0s
% Nosso modelo contem:
% - 1 entrada (uk = delta Giro/s)
% - 2 estados (x1 = Tilt usando Giro e  x2 = Drift)
% - 1 saida (yk = Tilt do acelerometro)
% portanto nosso modelo fica:
%
% x[k] = A*x[k-1] + B*u[k] + w[k]
% X1 = (x1 + x2 * deltaT) + (deltaT * uk) + ruido
% X2 = (x2) + ruido
%
% y[k] = C*x[k] + v[k]
% Y = X1 + ruido

deltaT = 1/freq_sample;
A = [1 deltaT; 0 1];
B = [deltaT; 0];
C = [1 0];
Q = [0.002^2 0; 0 0];
R = 0.03;

% Vari�vel de ajuste do filtro madgwick
beta=0.1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Vari�veis de dados
vazios=zeros(1,max_size); 
cont=0;                                 % Conta quantas amostras foram lidas

ax=vazios;                              % Acelera��o eixo X
ay=ax;                                  % Acelera��o eixo Y
az=ax;                                  % Acelera��o eixo Z
tp=ax;                                  % Temperatura do MPU
gx=ax;                                  % Giro/s eixo X
gy=ax;                                  % Giro/s eixo Y
gz=ax;                                  % Giro/s eixo Z
gPitch=ax;                              % Movimento de Pitch usando giro/s (relativo a ultima rota��o do corpo)
gRoll=ax;                               % Movimento de Roll usando giro/s (relativo a ultima rota��o do corpo)
gYaw=ax;                                % Movimento de Yaw usando giro/s (relativo a ultima rota��o do corpo)
gPitch_abs=ax;                          % Movimento de Pitch usando giro/s e matriz de rota��o (em rela��o a posi��o inicial do corpo)
gRoll_abs=ax;                           % Movimento de Roll usando giro/s e matriz de rota��o (em rela��o a posi��o inicial do corpo)
gYaw_abs=ax;                            % Movimento de Yaw usando giro/s e matriz de rota��o (em rela��o a posi��o inicial do corpo)
Rot=[[1,0,0];[0,1,0];[0,0,1]];          % Matriz de rota��o que move o corpo da posi��o inicial p/ a atual
aPitch=ax;                              % Movimento de Roll usando Acelera��o
aRoll=ax;                               % Movimento de Yaw usando Acelera��o
vx=ax;                                  % Velocidade no eixo X
vy=ax;                                  % Velocidade no eixo Y
vz=ax;                                  % Velocidade no eixo Z
px=ax;                                  % Posi��o no eixo X
py=ax;                                  % Posi��o no eixo Y
pz=ax;                                  % Posi��o no eixo Z
ax_without_gravity=ax;                  % Acelera��o eixo X removido a gravidade
ay_without_gravity=ax;                  % Acelera��o eixo Y removido a gravidade
az_without_gravity=ax;                  % Acelera��o eixo Z removido a gravidade
r_data=zeros(window_k,7);               % Dados n�o modificados (sem filtro ou media)
compl_Roll=ax;                          % Movimento de Roll usando filtro complementar
compl_Pitch=ax;                         % Movimento de Pitch usando filtro complementar
compl_Yaw=ax;                           % Movimento de Yaw usando filtro complementar
kalman_Roll=ax;                         % Movimento de Roll usando filtro de kalman
kalman_Pitch=ax;                        % Movimento de Pitch usando filtro de kalman
kalman_Yaw=ax;                          % Movimento de Yaw usando filtro de kalman
madgwick_Roll=ax;                       % Movimento de Roll usando filtro de madgwick
madgwick_Pitch=ax;                      % Movimento de Pitch usando filtro de madgwick
madgwick_Yaw=ax;                        % Movimento de Yaw usando filtro de madgwick
t = 0:max_size;                         % Eixo temporal do gr�fico

%% Define uma janela p/ plot
plot_1 = render(freq_render, layout);

% Obtem a lista de itens unicos definidos no layout
% para evitar calculo de itens desceness�rios
setted_objects_name = plot_1.setted_objects_name;

% Seta as labels de cada gr�fico
plot_1.setProperties(Acel, 'Acelera��o em "g"', 'Amostra', 'g', {'vX', 'vY', 'vZ'});
plot_1.setProperties(Vel, 'Velocidade em m/s', 'Amostra', 'm/s', {'vX', 'vY', 'vZ'});
plot_1.setProperties(Space, 'Espa�o em metros', 'Amostra', 'metros', {'X', 'Y', 'Z'});
plot_1.setProperties(Gvel, 'Giro em graus/seg', 'Amostra', 'graus/seg', {'gX', 'gY', 'gZ'});
plot_1.setProperties(Gdeg, 'Giro em graus(relativo)', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plot_1.setProperties(Gtilt, 'Giro em graus(absoluto)', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plot_1.setProperties(FusionTilt, 'Giro em graus(absoluto) usando acel + mag', 'Amostra', 'graus', {'aRoll', 'aPitch', 'mYaw'});
plot_1.setProperties(CompTilt, 'Filtro complementar', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plot_1.setProperties(KalmanTilt, 'Filtro de Kalman', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plot_1.setProperties(MadgwickTilt, 'Filtro de Madgwick', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plot_1.setProperties(Acel_G, 'Acelera��o em g sem gravidade', 'Amostra', 'g', {'aX', 'aY', 'aZ'});

% Seta a fonte de dados de cada gr�fico
plot_1.setSource(Acel, 'ax', 'ay', 'az');
plot_1.setSource(Vel, 'vx', 'vy', 'vz');
plot_1.setSource(Space, 'px', 'py', 'pz');
plot_1.setSource(Gvel, 'gx', 'gy', 'gz');
plot_1.setSource(Gdeg, 'gRoll', 'gPitch', 'gYaw');
plot_1.setSource(Gtilt, 'gRoll_abs', 'gPitch_abs', 'gYaw_abs');
plot_1.setSource(FusionTilt, 'aRoll', 'aPitch', 'vazios');
plot_1.setSource(CompTilt, 'compl_Roll', 'compl_Pitch', 'compl_Yaw');
plot_1.setSource(KalmanTilt, 'kalman_Roll', 'kalman_Pitch', 'kalman_Yaw');
plot_1.setSource(MadgwickTilt, 'madgwick_Roll', 'madgwick_Pitch', 'madgwick_Yaw');
plot_1.setSource(Acel_G, 'ax_without_gravity', 'ay_without_gravity', 'az_without_gravity');


%% Inicializa os filtros de kalman, um para cada eixo,
% podemos fazer tudo com um filtro s�, entretanto os par�metros ficariam
% bem grandes e de dificil visualiza��o
kalmanFilterRoll = kalman(A,B,C,Q,R);
kalmanFilterPitch = kalman(A,B,C,Q,R);
kalmanFilterYaw = kalman(A,B,C,Q,R);

%% Iniciaaliza o filtro de madgwick
madgwickFilter = MadgwickAHRS('SamplePeriod', 1/freq_sample, 'Beta', beta);

%% Abre porta serial
if read_from_serial
    reader_1 = reader();
    reader_1.set_serial_reader(serial_COM, serial_baudrate);
else
    reader_1 = reader();
    reader_1.set_file_reader(file_full_path, file_simulated_freq);
end

%% Obtem os dados e plota em tempo real
% NOTA: Se o buffer do serial encher (> 512 bytes) o programa pode explodir ou apresentar erros, caso isso ocorra
% abaixe a taxa de renderiza��o do gr�fico. Para verificar se erros ocorreram, compare a quantidade de amostras enviadas com a quantidade lida
while true
    
    %% L� uma amostra de cada da porta serial/arquivo
    data = reader_1.read_sample();

    % Se � o fim do arquivo ou deu algum erro finaliza
    if isempty(data)
        break;
    end

    cont=cont+1;
    
    data = str2double(data);
    
    %% Converter acelera��es em "g"
    data(1)=esc_ac*(data(1)/32767) - ax_bias;
    data(2)=esc_ac*(data(2)/32767) - ay_bias;
    data(3)=esc_ac*(data(3)/32767) - az_bias;

    %% Converter giros em "graus/seg"
    data(5)=esc_giro*(data(5)/32767) - gx_bias;
    data(6)=esc_giro*(data(6)/32767) - gy_bias;
    data(7)=esc_giro*(data(7)/32767) - gz_bias;

    %% Converter temperatura para Celsius
    data(4)=(data(4)/340)+36.53;

    %% Salva os dados sem altera��o p/ poder aplicar a media movel mais a frente
    r_data = [r_data(2:window_k,:) ; data(1:7)];

    %% Faz a media movel dos dados lidos
    data = sum(r_data) / window_k;
    
    %% Salva valores ap�s aplicar a media movel
    ax = [ax(2:max_size) data(1)];
    ay = [ay(2:max_size) data(2)];
    az = [az(2:max_size) data(3)];
    tp = [tp(2:max_size) data(4)];
    gx = [gx(2:max_size) data(5)];
    gy = [gy(2:max_size) data(6)];
    gz = [gz(2:max_size) data(7)];

    %% Calcula Yaw, Pitch e Roll realtivos(em rela��o a ultima rota��o do corpo) p/ a nova amostra usando giro
    % Usando o giro, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)
    if isOneIn(setted_objects_name, {Gdeg, Gtilt, FusionTilt, CompTilt})
        newPitch = (gPitch(max_size) + ((gy(max_size-1) + gy(max_size)) / (2 * freq_sample) ));
        newRoll = (gRoll(max_size) + ((gx(max_size-1) + gx(max_size)) / (2 * freq_sample) ));
        newYaw = (gYaw(max_size) + ((gz(max_size-1) + gz(max_size)) / (2 * freq_sample) ));

        gPitch  = [gPitch(2:max_size) newPitch];
        gRoll   = [gRoll(2:max_size)  newRoll];
        gYaw    = [gYaw(2:max_size)   newYaw];
    end
    
    %% Calcula a matriz de rota��o (X,Y,Z) que foi respons�vel por mover o corpo da posi��o da amostra anterior para a atual
    % Ref do calculo: https://www.youtube.com/watch?v=wg9bI8-Qx2Q
    if isOneIn(setted_objects_name, {Gtilt, FusionTilt, CompTilt})
        delta_gPitch = gPitch(max_size) - gPitch(max_size-1);
        delta_gRoll = gRoll(max_size) - gRoll(max_size-1);
        delta_gYaw = gYaw(max_size) - gYaw(max_size-1);
        temp_Rx = [...
            [1,                0,               0        ];...
            [0,     cosd(delta_gRoll),  -sind(delta_gRoll)];...
            [0,     sind(delta_gRoll),  cosd(delta_gRoll)]
        ];
        temp_Ry = [...
            [cosd(delta_gPitch),        0,       sind(delta_gPitch)];...
            [0,                         1,               0        ];...
            [-sind(delta_gPitch),        0,      cosd(delta_gPitch)]
        ];
        temp_Rz = [...
            [cosd(delta_gYaw),         -sind(delta_gYaw),       0];...
            [sind(delta_gYaw),         cosd(delta_gYaw),       0];...
            [0,                         0,                      1]
        ];
        temp_R = temp_Rx * temp_Ry * temp_Rz;

        % Calcula a matriz de rota��o (X,Y,Z) que move o corpo da posi��o inicial para a posi��o atual
        Rot = Rot * temp_R;


        %% Extrai Yaw, Pitch e Roll absolutos(em rela��o a posi��o inicial do corpo) p/ a nova amostra usando a atual matriz de rota��o (X,Y,Z)
        % Ref do calculo: https://www.youtube.com/watch?v=wg9bI8-Qx2Q
        newRoll = atan2(Rot(3,2), Rot(3,3)) * 180/pi;
        newYaw = atan2(Rot(2,1), Rot(1,1)) * 180/pi;
        if cosd(newYaw) == 0
            newPitch = atan2(-Rot(3,1), Rot(2,1)/sind(newYaw)) * 180/pi;
        else
            newPitch = atan2(-Rot(3,1), Rot(1,1)/cosd(newYaw)) * 180/pi;
        end

        gPitch_abs = [gPitch_abs(2:max_size) newPitch];
        gRoll_abs = [gRoll_abs(2:max_size) newRoll];
        gYaw_abs = [gYaw_abs(2:max_size) newYaw];
    end
    
    %% Calcula Yaw, Pitch e Roll absolutos(em rela��o a posi��o inicial do corpo) p/ a nova amostra usando acelera��o
    % Usando a acelera��o, usamos o vetor de gravidade que deve sempre
    % estar presente p/ determinar a posi��o do corpo
    % assim temos que p/ a order de rota��o X,Y,Z
    % Ref do calculo: https://www.nxp.com/docs/en/application-note/AN3461.pdf
    if isOneIn(setted_objects_name, {FusionTilt, CompTilt, KalmanTilt, Acel_G, Vel, Space})
        newPitch = atan2(-ax(max_size), sqrt( ay(max_size)^2 + az(max_size)^2 )) * 180/pi;
        if (az(max_size)>=0)
            sign = 1;
        else
            sign = -1;
        end
        miu = 0.001;
        newRoll = atan2( ay(max_size),   (sign * sqrt( az(max_size)^2 + miu * ax(max_size)^2 ))) * 180/pi;

        aPitch  = [aPitch(2:max_size) newPitch];
        aRoll   = [aRoll(2:max_size)   newRoll];
    end

    %% Calcula rota��o usando filtro complementar
    % Ref do calculo: https://www.youtube.com/watch?v=whSw42XddsU
    if isOneIn(setted_objects_name, CompTilt)
        newRoll = (1-mu)*(compl_Roll(max_size) + delta_gRoll) + mu*aRoll(max_size);
        newPitch = (1-mu)*(compl_Pitch(max_size) + delta_gPitch) + mu*aPitch(max_size);
        % newYaw = 

        compl_Roll = [compl_Roll(2:max_size) newRoll];
        compl_Pitch = [compl_Pitch(2:max_size) newPitch];
        % compl_Yaw = [compl_Yaw(2:max_size) newYaw]
    end

    %% Calcula rota��o usando filtro de Kalman
    % Ref do calculo: https://www.youtube.com/watch?v=urhaoECmCQk
    % e https://www.researchgate.net/publication/261038357_Embedded_Kalman_Filter_for_Inertial_Measurement_Unit_IMU_on_the_ATMega8535
    if isOneIn(setted_objects_name, {KalmanTilt, Acel_G, Vel, Space})
        % Calcula a predi��o p/ cada eixo individualmente
        kalmanFilterRoll.predict(gx(max_size));
        kalmanFilterPitch.predict(gy(max_size));

        % Atualiza a predi��o p/ cada eixo individualmente
        roll_and_bias = kalmanFilterRoll.update(aRoll(max_size));
        pitch_and_bias = kalmanFilterPitch.update(aPitch(max_size));

        % Insere o valor filtrado no eixo a ser plotado
        kalman_Roll = [kalman_Roll(2:max_size)  roll_and_bias(1)];
        kalman_Pitch = [kalman_Pitch(2:max_size)  pitch_and_bias(1)];
    end
    
    %% Calcula rota��o usando filtro de madgwick
    % Ref do calculo: https://nitinjsanket.github.io/tutorials/attitudeest/madgwick
    % e https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/
    if isOneIn(setted_objects_name, MadgwickTilt)
        gyroscope = [gx(max_size), gy(max_size), gz(max_size)] * (pi/180) ;
        accelerometer = [ax(max_size), ay(max_size), az(max_size)];
        madgwickFilter.UpdateIMU(gyroscope, accelerometer);

        % Converte o resultado do filtro de quaternion para angulos absolutos (relativo a terra) em euler

        euler = quatern2euler(quaternConj(madgwickFilter.Quaternion)) * (180/pi);
        madgwick_Roll = [madgwick_Roll(2:max_size)      euler(1)];
        madgwick_Pitch = [madgwick_Pitch(2:max_size)    euler(2)];
        madgwick_Yaw = [madgwick_Yaw(2:max_size)        euler(3)];
    end
    
    
    %% Calcula a acelera��o removendo a gravidade
    % Obtem o vetor gravidade atual rotacionando em sentido contr�rio realizado pelo corpo, considerando gravidade = 1g
    % e usando os dados do filtro de kalman p/ roll e pitch e do girosc�pio p/ yaw
    % Ref do calculo: https://www.nxp.com/docs/en/application-note/AN3461.pdf
    if isOneIn(setted_objects_name, {Acel_G, Vel, Space})
        gravity_vector =   [-sind(kalman_Pitch(max_size)),...
                             cosd(kalman_Pitch(max_size))*sind(kalman_Roll(max_size)),...
                             cosd(kalman_Pitch(max_size))*cosd(kalman_Roll(max_size))
                           ];
        ax_without_gravity = [ax_without_gravity(2:max_size) (ax(max_size) - gravity_vector(1))];
        ay_without_gravity = [ay_without_gravity(2:max_size) (ay(max_size) - gravity_vector(2))];
        az_without_gravity = [az_without_gravity(2:max_size) (az(max_size) - gravity_vector(3))];
    end

    %% Calcula Velocidade integrando a acelera��o
    % Usando a acelera��o, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)
    if isOneIn(setted_objects_name, {Vel, Space})
        newVx = (vx(max_size) + ((ax_without_gravity(max_size-1) + ax_without_gravity(max_size)) / (2 * freq_sample) ));
        newVy = (vy(max_size) + ((ay_without_gravity(max_size-1) + ay_without_gravity(max_size)) / (2 * freq_sample) ));
        newVz = (vz(max_size) + ((az_without_gravity(max_size-1) + az_without_gravity(max_size)) / (2 * freq_sample) ));

        vx = [vx(2:max_size)  newVx];
        vy = [vy(2:max_size)  newVy];
        vz = [vz(2:max_size)  newVz];
    end

    %% Calcula Posi��o integrando a Velocidade
    % Usando a Velocidade, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)
    if isOneIn(setted_objects_name, Space)
        newPx = (px(max_size) + ((vx(max_size-1) + vx(max_size)) / (2 * freq_sample) ));
        newPy = (py(max_size) + ((vy(max_size-1) + vy(max_size)) / (2 * freq_sample) ));
        newPz = (pz(max_size) + ((vz(max_size-1) + vz(max_size)) / (2 * freq_sample) ));

        px = [px(2:max_size)  newPx];
        py = [py(2:max_size)  newPy];
        pz = [pz(2:max_size)  newPz];
    end
  
    %% Tenta redesenhar o plot, se deu o tempo da frequencia
    if plot_in_real_time
        plot_1.try_render();
    end
end

%% Renderiza pela ultima vez, independente de ter dado o tempo da frequencia
plot_1.force_render();

%% Linka todos os eixos p/ poder dar zoom em todos de uma vez, so pode ser executado quando n�o tiver mais atualiza��es
% plot_1.linkAllAxes();

%% Aqui acaba o script
fprintf(1,'Recebidos %d amostras\n\n',cont);
reader_1.delete();
return;