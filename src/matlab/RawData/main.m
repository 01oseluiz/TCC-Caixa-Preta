% Ler da porta serial
% Ainda precisa melhorar
% BUGS:
% - file_simulated_freq ainda n�o funciona muito bem

addpath('quaternion_library');      % include quaternion library
addpath('render');                  % include plot library
addpath('reader');                  % include reader library
addpath('kalman');                  % include kalman filter class
addpath('madgwick');                % include madgwick filter class
addpath('helpers');                 % include some useful functions

close all;                          % close all figures
clear;                              % clear all variables
clc;                                % clear the command terminal

% layout Macros
Vazio = '';                                 % Deixa a celula vazia
Acel = 'A';                                 % Acelera��o X,Y,Z
Vel = 'B';                                  % Velocidade X,Y,Z
Space = 'C';                                % Espa�o percorrido X,Y,Z
Gvel = 'D';                                 % Velocidade angular em X,Y,Z
Gdeg = 'E';                                 % Posi��o angular em Z,Y,X relativo (em rela��o a Posi��o anterior)
Gtilt = 'F';                                % Posi��o angular em Z,Y,X absoluto (em rela��o aos eixos iniciais)
Mag = 'G';                                  % Magnetometro
FusionTilt = 'H';                           % Posi��o angular em Z,Y,X absoluto, usando Acelera��o e magnetometro
CompTilt = 'I';                             % Posi��o angular usando o filtro complementar
KalmanTilt = 'J';                           % Posi��o angular usando o filtro de kalman
MadgwickTilt = 'K';                         % Posi��o angular usando o filtro de madgwick
Quat = 'L';                                 % Plot dos valores de quaternions obtidos pno filtro de madgwick
Acel_G = 'M';                               % Acelera��o desconsiderando a gravidade (utilizando o melhor filtro p/ remove-la)
Quat = 'N';                                 % Plot com os valore de quaternion extraidos do filtro de madgwick
Card3DGdeg = 'O';                           % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (Gdeg)
Card3DGtilt = 'P';                          % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (Gtilt)
Card3DFusion = 'Q';                         % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (FusionTilt)
Card3DComp = 'R';                           % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (CompTilt)
Card3DKalman = 'S';                         % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (KalmanTilt)
Card3DMadgwick = 'T';                       % Posi��o angular atual usando um objeto 3D rotacionando utilizando quaternios advindos do filtro de Madgwick
CompassLine = 'U';                          % Angulo de yaw estraido do magnetometro sem compensa��o de tilt plotado em plano cartesiano
Compass = 'V';                              % Angulo de yaw estraido do magnetometro sem compensa��o de tilt plotado em plano polar
Space3D = 'X';                              % Posi��o em um Espa�o 3D
                                            % pois � necess�rio saber bem a Posi��o angular p/ isso)

%% PARAMETROS DE USU�RIO %%
% Fonte de leitura
read_from_serial=true;     % Set to false to use a file
serial_COM='COM4';          
serial_baudrate=115200;     
file_full_path='Dados/d008$.txt';

% Amostragem
max_size=4000;              % Quantidade maxima de amostras exibidas na tela
freq_sample=100;            % Frequencia da amostragem dos dados

% Plotagem
plot_in_real_time=true;     % Define se o plot ser� so no final, ou em tempo real
freq_render=5;               % Frequencia de atualiza��o do plot
layout= {...                 % Layout dos plots, as visualiza��es poss�veis est�o variaveis no inicio do arquivo

        CompassLine,   CompassLine;...
        MadgwickTilt, MadgwickTilt;...
        Card3DMadgwick, Vazio;...
     
};                          % OBS: Repita o nome no layout p/ expandir o plot em varios grids

% Constantes do sensor
const_g=9.8;                % Constante gravitacional segundo fabricante do MPU
gx_bias=-1.05;              % 
gy_bias=0.16;               % 
gz_bias=-0.2;               % 
ax_bias=0.018;              % 
ay_bias=0.034;              % 
az_bias=0.03;               % 
hx_offset=-70;          % 
hy_offset=228;          % 
hz_offset=10;           % 
hx_scale=1.020833;    % 
hy_scale=0.940048;    % 
hz_scale=1.045333;    % 
esc_ac=2;                   % Vem do Arduino, fun��o que configura escalas de Acelera��o
esc_giro=250;               % e giro //+/- 2g e +/-250gr/seg


% Media movel parametros 
window_k = 10;              % Janela da media movel (minimo = 2)

% Vari�vel de ajuste do filtro complementar
mu=0.02;

% Vari�vel de ajuste do filtro de kalman, os valores iniciais de X e P s�o por padr�o 0s
% Nosso modelo countem:
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
count=0;                                 % conta quantas amostras foram lidas

ax=vazios;                              % Acelera��o eixo X
ay=ax;                                  % Acelera��o eixo Y
az=ax;                                  % Acelera��o eixo Z
gx=ax;                                  % Giro/s eixo X
gy=ax;                                  % Giro/s eixo Y
gz=ax;                                  % Giro/s eixo Z
hx=ax;                                  % Leitura do magnetometro X
hy=ax;                                  % Leitura do magnetometro Y
hz=ax;                                  % Leitura do magnetometro Z
gPitch=ax;                              % Movimento de Pitch usando giro/s (relativo a ultima Rota��o do corpo)
gRoll=ax;                               % Movimento de Roll usando giro/s (relativo a ultima Rota��o do corpo)
gYaw=ax;                                % Movimento de Yaw usando giro/s (relativo a ultima Rota��o do corpo)
gPitch_abs=ax;                          % Movimento de Pitch usando giro/s e matriz de Rota��o (em rela��o a Posi��o inicial do corpo)
gRoll_abs=ax;                           % Movimento de Roll usando giro/s e matriz de Rota��o (em rela��o a Posi��o inicial do corpo)
gYaw_abs=ax;                            % Movimento de Yaw usando giro/s e matriz de Rota��o (em rela��o a Posi��o inicial do corpo)
Rot=[[1,0,0];[0,1,0];[0,0,1]];          % Matriz de Rota��o que move o corpo da Posi��o inicial p/ a atual
aPitch=ax;                              % Movimento de Pitch usando Acelera��o
aRoll=ax;                               % Movimento de Roll usando Acelera��o
mYaw=ax;                                % Movimento de Yaw usando Magnet�metro
vx=ax;                                  % Velocidade no eixo X
vy=ax;                                  % Velocidade no eixo Y
vz=ax;                                  % Velocidade no eixo Z
px=ax;                                  % Posi��o no eixo X
py=ax;                                  % Posi��o no eixo Y
pz=ax;                                  % Posi��o no eixo Z
ax_without_gravity=ax;                  % Acelera��o eixo X removido a gravidade
ay_without_gravity=ax;                  % Acelera��o eixo Y removido a gravidade
az_without_gravity=ax;                  % Acelera��o eixo Z removido a gravidade
r_data=zeros(window_k,9);               % Dados n�o modificados (sem filtro ou media)
compl_Roll=ax;                          % Movimento de Roll usando filtro complementar
compl_Pitch=ax;                         % Movimento de Pitch usando filtro complementar
compl_Yaw=ax;                           % Movimento de Yaw usando filtro complementar
kalman_Roll=ax;                         % Movimento de Roll usando filtro de kalman
kalman_Pitch=ax;                        % Movimento de Pitch usando filtro de kalman
kalman_Yaw=ax;                          % Movimento de Yaw usando filtro de kalman
madgwick_Roll=ax;                       % Movimento de Roll usando filtro de madgwick
madgwick_Pitch=ax;                      % Movimento de Pitch usando filtro de madgwick
madgwick_Yaw=ax;                        % Movimento de Yaw usando filtro de madgwick
q1=ax;                                  % Quaternio 1 do filtro de madgwick
q2=ax;                                  % Quaternio 2 do filtro de madgwick
q3=ax;                                  % Quaternio 3 do filtro de madgwick
q4=ax;                                  % Quaternio 4 do filtro de madgwick
compass_ang=ax;                         % Compass sem compensa��o de tilt usando magnetometro - medido em graus

%% Define uma janela p/ plot
plot_1 = Render(freq_render, layout);


% Obtem a lista de itens unicos definidos no layout
% para evitar calculo de itens desceness�rios
setted_objects_name = plot_1.setted_objects_name;

% Seta os tipos de cada gr�fico
plotAcel = plot_1.setItemType(Acel, 'plotline');
plotVel = plot_1.setItemType(Vel, 'plotline');
plotSpace = plot_1.setItemType(Space, 'plotline');
plotGvel = plot_1.setItemType(Gvel, 'plotline');
plotGdeg = plot_1.setItemType(Gdeg, 'plotline');
plotGtilt = plot_1.setItemType(Gtilt, 'plotline');
plotMag = plot_1.setItemType(Mag, 'plotline');
plotFusionTilt = plot_1.setItemType(FusionTilt, 'plotline');
plotCompTilt = plot_1.setItemType(CompTilt, 'plotline');
plotKalmanTilt = plot_1.setItemType(KalmanTilt, 'plotline');
plotMadgwickTilt = plot_1.setItemType(MadgwickTilt, 'plotline');
plotQuat = plot_1.setItemType(Quat, 'plotline');
plotAcel_G = plot_1.setItemType(Acel_G, 'plotline');
plotCard3DGdeg = plot_1.setItemType(Card3DGdeg, 'plot3dcar');
plotCard3DMadgwick = plot_1.setItemType(Card3DMadgwick, 'plot3dcar');
plotCard3DGtilt = plot_1.setItemType(Card3DGtilt, 'plot3dcar');
plotCard3DFusion = plot_1.setItemType(Card3DFusion, 'plot3dcar');
plotCard3DKalman = plot_1.setItemType(Card3DKalman, 'plot3dcar');
plotCard3DComp = plot_1.setItemType(Card3DComp, 'plot3dcar');
plotSpace3D = plot_1.setItemType(Space3D, 'plot3dline');
plotCompassLine = plot_1.setItemType(CompassLine, 'plotline');
plotCompass = plot_1.setItemType(Compass, 'plotcompass');

% Seta a fonte de dados de cada gr�fico
plotAcel.setSource({'ax', 'ay', 'az'}, {'r', 'g', 'b'});
plotVel.setSource({'vx', 'vy', 'vz'}, {'r', 'g', 'b'});
plotSpace.setSource({'px', 'py', 'pz'}, {'r', 'g', 'b'});
plotGvel.setSource({'gx', 'gy', 'gz'}, {'r', 'g', 'b'});
plotGdeg.setSource({'gRoll', 'gPitch', 'gYaw'}, {'r', 'g', 'b'});
plotGtilt.setSource({'gRoll_abs', 'gPitch_abs', 'gYaw_abs'}, {'r', 'g', 'b'});
plotMag.setSource({'hx', 'hy', 'hz'}, {'r', 'g', 'b'});
plotFusionTilt.setSource({'aRoll', 'aPitch'}, {'r', 'g'});
plotCompTilt.setSource({'compl_Roll', 'compl_Pitch'}, {'r', 'g'});
plotKalmanTilt.setSource({'kalman_Roll', 'kalman_Pitch'}, {'r', 'g'});
plotMadgwickTilt.setSource({'madgwick_Roll', 'madgwick_Pitch', 'madgwick_Yaw'}, {'r', 'g', 'b'});
plotQuat.setSource({'q1', 'q2', 'q3', 'q4'}, {'r', 'g', 'b', 'y'});
plotAcel_G.setSource({'ax_without_gravity', 'ay_without_gravity', 'az_without_gravity'}, {'r', 'g', 'b'});
plotCard3DGdeg.setCar();
plotCard3DMadgwick.setCar();
plotCard3DGtilt.setCar();
plotCard3DFusion.setCar();
plotCard3DKalman.setCar();
plotCard3DComp.setCar();
plotSpace3D.setSource({'px', 'py', 'pz'});
plotCompassLine.setSource({'compass_ang'}, {'r'});
plotCompass.setCompass();

% Seta as labels de cada gr�fico
plotAcel.setProperties('Acelera��o em "g"', 'Amostra', 'g', {'vX', 'vY', 'vZ'});
plotVel.setProperties('Velocidade em m/s', 'Amostra', 'm/s', {'vX', 'vY', 'vZ'});
plotSpace.setProperties('Espa�o em metros', 'Amostra', 'metros', {'X', 'Y', 'Z'});
plotGvel.setProperties('Giro em graus/seg', 'Amostra', 'graus/seg', {'gX', 'gY', 'gZ'});
plotGdeg.setProperties('Giro em graus(relativo)', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plotGtilt.setProperties('Giro em graus(absoluto)', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plotMag.setProperties('Magnetrometro em mili Gaus', 'Amostra', 'mG', {'hx', 'hy', 'hz'});
plotFusionTilt.setProperties('Giro em graus(absoluto) usando acel + mag', 'Amostra', 'graus', {'aRoll', 'aPitch'});
plotCompTilt.setProperties('Filtro complementar', 'Amostra', 'graus', {'Roll', 'Pitch'});
plotKalmanTilt.setProperties('Filtro de Kalman', 'Amostra', 'graus', {'Roll', 'Pitch'});
plotMadgwickTilt.setProperties('Filtro de Madgwick', 'Amostra', 'graus', {'Roll', 'Pitch', 'Yaw'});
plotQuat.setProperties('Quaterions do filtro de Madgwick', 'Amostra', 'val', {'q1', 'q2', 'q3', 'q4'});
plotAcel_G.setProperties('Acelera��o em g sem gravidade', 'Amostra', 'g', {'aX', 'aY', 'aZ'});
plotCard3DGdeg.setProperties('Rota��o 3D usando Posi��o angular relativa');
plotCard3DMadgwick.setProperties('Rota��o 3D usando quaternions (filtro Madgwick)');
plotCard3DGtilt.setProperties('Rota��o 3D usando Posi��o angular absoluta');
plotCard3DFusion.setProperties('Rota��o 3D usando acel e mag');
plotCard3DComp.setProperties('Rota��o 3D usando filtro complementar');
plotCard3DKalman.setProperties('Rota��o 3D usando filtro de kalman');
plotSpace3D.setProperties('Posi��o 3D (usando filtro de kalman)');
plotCompassLine.setProperties('Magnetic Heading sem compensa��o de tilt', 'Amostra', 'graus', {'Yaw'});
plotCompass.setProperties('Magnetic Heading sem compensa��o de tilt');

%% Inicializa os filtros de kalman, um para cada eixo,
% podemos fazer tudo com um filtro s�, entretanto os par�metros ficariam
% bem grandes e de dificil visualiza��o
kalmanFilterRoll = Kalman(A,B,C,Q,R);
kalmanFilterPitch = Kalman(A,B,C,Q,R);
kalmanFilterYaw = Kalman(A,B,C,Q,R);

%% Iniciaaliza o filtro de madgwick
madgwickFilter = MadgwickAHRS('SamplePeriod', 1/freq_sample, 'Beta', beta);

%% Abre porta serial / arquivo
if read_from_serial
    reader = ReaderSerial(serial_COM, serial_baudrate);
else
    reader = ReaderFile(file_full_path);
end

%% Obtem os dados e plota em tempo real
% NOTA: Se o buffer do serial encher (> 512 bytes) o programa pode explodir ou apresentar erros, caso isso ocorra
% abaixe a taxa de renderiza��o do gr�fico. Para verificar se erros ocorreram, compare a quantidade de amostras enviadas com a quantidade lida
while true
    
    %% L� uma amostra de cada da porta serial/arquivo
    data = reader.read_sample();

    % Se � o fim do arquivo ou deu algum erro finaliza
    if isempty(data)
        break;
    end

    count=count+1;
    
    data = str2int16(data);
    
    %% Converter acelera��o em "g"
    data(1)=esc_ac*(data(1)/32767) - ax_bias;
    data(2)=esc_ac*(data(2)/32767) - ay_bias;
    data(3)=esc_ac*(data(3)/32767) - az_bias;

    %% Converter giros em "graus/seg"
    data(4)=esc_giro*(data(4)/32767) - gx_bias;
    data(5)=esc_giro*(data(5)/32767) - gy_bias;
    data(6)=esc_giro*(data(6)/32767) - gz_bias;

    %% Remove hard and soft iron dos dados do magnetometro
    data(7) = (data(7) - hx_offset) * hx_scale;
    data(8) = (data(8) - hy_offset) * hy_scale;
    data(9) = (data(9) - hz_offset) * hz_scale;

    %% Converter leitura do magnetometro em micro Testla p/ mili Gaus
    data(7) = (4912 * data(7)/32767) * 10;
    data(8) = (4912 * data(8)/32767) * 10;
    data(9) = (4912 * data(9)/32767) * 10;

    %% Salva os dados sem altera��o p/ poder aplicar a media movel mais a frente
    r_data = [r_data(2:window_k,:) ; data(1:9)];

    %% Faz a media movel dos dados lidos
    data = sum(r_data) / window_k;
    
    %% Salva valores ap�s aplicar a media movel
    ax = [ax(2:max_size) data(1)];
    ay = [ay(2:max_size) data(2)];
    az = [az(2:max_size) data(3)];
    gx = [gx(2:max_size) data(4)];
    gy = [gy(2:max_size) data(5)];
    gz = [gz(2:max_size) data(6)];
    hx = [hx(2:max_size) data(7)];
    hy = [hy(2:max_size) data(8)];
    hz = [hz(2:max_size) data(9)];

    %% Calcula Yaw, Pitch e Roll realtivos(em rela��o a ultima Rota��o do corpo) p/ a nova amostra usando giro
    % Usando o giro, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)
    if isOneIn(setted_objects_name, {Gdeg, Gtilt, FusionTilt, CompTilt, Card3DGdeg, Card3DGtilt, Card3DFusion, Card3DComp})
        newPitch = (gPitch(max_size) + ((gy(max_size-1) + gy(max_size)) / (2 * freq_sample) ));
        newRoll = (gRoll(max_size) + ((gx(max_size-1) + gx(max_size)) / (2 * freq_sample) ));
        newYaw = (gYaw(max_size) + ((gz(max_size-1) + gz(max_size)) / (2 * freq_sample) ));

        gPitch  = [gPitch(2:max_size) newPitch];
        gRoll   = [gRoll(2:max_size)  newRoll];
        gYaw    = [gYaw(2:max_size)   newYaw];
    end
    
    %% Calcula a matriz de Rota��o (Z,Y,X) que foi respons�vel por mover o corpo da Posi��o da amostra anterior para a atual
    % Ref do calculo: https://www.youtube.com/watch?v=wg9bI8-Qx2Q
    if isOneIn(setted_objects_name, {Gtilt, FusionTilt, CompTilt, Card3DGtilt, Card3DFusion, Card3DComp})
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
        temp_R = temp_Rz * temp_Ry * temp_Rx;

        % Calcula a matriz de Rota��o (Z,Y,X) que move o corpo da Posi��o inicial para a Posi��o atual
        Rot = Rot * temp_R;


        %% Extrai Yaw, Pitch e Roll absolutos(em rela��o a Posi��o inicial do corpo) p/ a nova amostra usando a atual matriz de Rota��o (Z,Y,X)
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

    %% Calcula Compass sem compensa��o 
    % Ref do calculo: https://blog.digilentinc.com/how-to-convert-magnetometer-data-into-compass-heading/
    if isOneIn(setted_objects_name, {CompassLine, Compass})
        newYaw = atan2(hy(max_size), hx(max_size)) * 180/pi;

        if newYaw > 360
            newYaw = newYaw - 360;
        elseif newYaw < 0
            newYaw = newYaw + 360;
        end

        compass_ang = [compass_ang(2:max_size) newYaw];
    end

    %% Plota em plano polar o Compass sem compensa��o 
    if isOneIn(setted_objects_name, {Compass})
        plotCompass.rotateCompass(compass_ang(max_size));
    end

    %% Calcula Yaw, Pitch e Roll absolutos(em rela��o a Posi��o inicial do corpo) p/ a nova amostra usando Acelera��o
    % Usando a Acelera��o, usamos o vetor de gravidade que deve sempre
    % estar presente p/ determinar a Posi��o do corpo
    % assim temos que p/ a orderm de Rota��o Z,Y,X
    % Ref do calculo: https://www.nxp.com/docs/en/application-note/AN3461.pdf
    if isOneIn(setted_objects_name, {FusionTilt, CompTilt, KalmanTilt, Acel_G, Vel, Space, Card3DFusion, Card3DKalman, Card3DComp, Space3D})
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

    %% Calcula Rota��o usando filtro complementar
    % Ref do calculo: https://www.youtube.com/watch?v=whSw42XddsU
    if isOneIn(setted_objects_name, {CompTilt, Card3DComp})
        newRoll = (1-mu)*(compl_Roll(max_size) + delta_gRoll) + mu*aRoll(max_size);
        newPitch = (1-mu)*(compl_Pitch(max_size) + delta_gPitch) + mu*aPitch(max_size);
        % newYaw = 

        compl_Roll = [compl_Roll(2:max_size) newRoll];
        compl_Pitch = [compl_Pitch(2:max_size) newPitch];
        % compl_Yaw = [compl_Yaw(2:max_size) newYaw]
    end

    %% Calcula Rota��o usando filtro de Kalman
    % Ref do calculo: https://www.youtube.com/watch?v=urhaoECmCQk
    % e https://www.researchgate.net/publication/261038357_Embedded_Kalman_Filter_for_Inertial_Measurement_Unit_IMU_on_the_ATMega8535
    if isOneIn(setted_objects_name, {KalmanTilt, Acel_G, Vel, Space, Card3DKalman, Space3D})
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
    
    %% Calcula Rota��o usando filtro de madgwick
    % Ref do calculo: https://nitinjsanket.github.io/tutorials/attitudeest/madgwick
    % e https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/
    if isOneIn(setted_objects_name, {MadgwickTilt, Card3DMadgwick, Quat})
        gyroscope = [gx(max_size), gy(max_size), gz(max_size)] * (pi/180) ;
        accelerometer = [ax(max_size), ay(max_size), az(max_size)];
        magnetometer = [hx(max_size), hy(max_size), hz(max_size)];
        madgwickFilter.Update(gyroscope, accelerometer, magnetometer);

        % Converte o resultado do filtro de quaternion para angulos absolutos (relativo a terra) em euler

        euler = quatern2euler(quaternConj(madgwickFilter.Quaternion)) * (180/pi);
        madgwick_Roll = [madgwick_Roll(2:max_size)      euler(1)];
        madgwick_Pitch = [madgwick_Pitch(2:max_size)    euler(2)];
        madgwick_Yaw = [madgwick_Yaw(2:max_size)        euler(3)];
    end

    %% Plota quaterions do filtro de madgwick
    if isOneIn(setted_objects_name, {Quat})
        q1 = [q1(2:max_size)    madgwickFilter.Quaternion(1)];
        q2 = [q2(2:max_size)    madgwickFilter.Quaternion(2)];
        q3 = [q3(2:max_size)    madgwickFilter.Quaternion(3)];
        q4 = [q4(2:max_size)    madgwickFilter.Quaternion(4)];
    end
    
    %% Calcula a Acelera��o removendo a gravidade
    % Obtem o vetor gravidade atual rotacionando em sentido countr�rio realizado pelo corpo, considerando gravidade = 1g
    % e usando os dados do filtro de kalman p/ roll e pitch e do girosc�pio p/ yaw
    % Ref do calculo: https://www.nxp.com/docs/en/application-note/AN3461.pdf
    if isOneIn(setted_objects_name, {Acel_G, Vel, Space, Space3D})
        gravity_vector =   [-sind(kalman_Pitch(max_size)),...
                             cosd(kalman_Pitch(max_size))*sind(kalman_Roll(max_size)),...
                             cosd(kalman_Pitch(max_size))*cosd(kalman_Roll(max_size))
                           ];
        ax_without_gravity = [ax_without_gravity(2:max_size) (ax(max_size) - gravity_vector(1))];
        ay_without_gravity = [ay_without_gravity(2:max_size) (ay(max_size) - gravity_vector(2))];
        az_without_gravity = [az_without_gravity(2:max_size) (az(max_size) - gravity_vector(3))];
    end

    %% Calcula Velocidade integrando a Acelera��o
    % Usando a Acelera��o, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)
    if isOneIn(setted_objects_name, {Vel, Space, Space3D})
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
    if isOneIn(setted_objects_name, {Space, Space3D})
        newPx = (px(max_size) + ((vx(max_size-1) + vx(max_size)) / (2 * freq_sample) ));
        newPy = (py(max_size) + ((vy(max_size-1) + vy(max_size)) / (2 * freq_sample) ));
        newPz = (pz(max_size) + ((vz(max_size-1) + vz(max_size)) / (2 * freq_sample) ));

        px = [px(2:max_size)  newPx];
        py = [py(2:max_size)  newPy];
        pz = [pz(2:max_size)  newPz];
    end

    %% Plota o carro em 3d, podendo ser usado qualquer um dos dados para rotacionar o objeto (Rota��o absoluta, relativa, filtro de kalman ...)
    if isOneIn(setted_objects_name, Card3DGdeg)
        plotCard3DGdeg.rotateWithEuler(gRoll(max_size), gPitch(max_size), gYaw(max_size));
    end

    if isOneIn(setted_objects_name, Card3DGtilt)
        plotCard3DGtilt.rotateWithEuler(gRoll_abs(max_size), gPitch_abs(max_size), gYaw_abs(max_size));
    end

    if isOneIn(setted_objects_name, Card3DFusion)
        plotCard3DFusion.rotateWithEuler(aRoll(max_size), aPitch(max_size), mYaw(max_size));
    end

    if isOneIn(setted_objects_name, Card3DComp)
        plotCard3DComp.rotateWithEuler(compl_Roll(max_size), compl_Pitch(max_size), compl_Yaw(max_size));
    end

    if isOneIn(setted_objects_name, Card3DKalman)
        plotCard3DKalman.rotateWithEuler(kalman_Roll(max_size), kalman_Pitch(max_size), kalman_Yaw(max_size));
    end

    if isOneIn(setted_objects_name, Card3DMadgwick)
        plotCard3DMadgwick.rotateWithQuaternion(madgwickFilter.Quaternion);
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
fprintf(1,'Recebidos %d amostras\n\n',count);
reader.delete();
return;