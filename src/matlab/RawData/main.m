% Ler da porta serial
% Ainda precisa melhorar
% BUGS:
% - file_simulated_freq ainda n�o funciona muito bem

addpath('quaternion_library');      % include quaternion library
addpath('render');                  % include plot library
addpath('reader');                  % include reader library
addpath('helpers');                 % include some useful functions
addpath('funcs');                   % 
addpath('plots');                   % 

close all;                          % close all figures
clear;                              % clear all variables
clc;                                % clear the command terminal

% Inst�ncia os plots
aceleration = Aceleration();
gyroscope = Gyroscope();
magnetometer = Magnetometer();
gyro_relative_tilt = GyroRelativeTilt();
gyro_absolute_tilt = GyroAbsoluteTilt();
acel_mag_tilt = AcelMagTilt();
comp_tilt = CompTilt();
acel_without_g = AcelWithoutG();
velocity = Velocity();
position = Position();
kalman_tilt = KalmanTilt();
Madgwick_tilt = MadgwickTilt();
quaternion = Quaternion();
compass = Compass();
compass_compensated = CompassCompensated();
car_3d_gdeg = Car3DGdeg();
car_3d_gtilt = Car3DGtilt();
car_3d_acelMag = Car3DAcelMag();
car_3d_comp = Car3DComp();
car_3d_kalman = Car3DKalman();
car_3d_madgwick = Car3DMadgwick();


% layout Macros
Vazio = '';                         % Deixa a celula vazia
Acel = aceleration.name;                         % Acelera��o X,Y,Z
Vel = velocity.name;                          % Velocidade X,Y,Z
Space = position.name;                        % Espa�o percorrido X,Y,Z
Gvel = gyroscope.name;                         % Velocidade angular em X,Y,Z
Gdeg = gyro_relative_tilt.name;                         % Posi��o angular em Z,Y,X relativo (em rela��o a Posi��o anterior)
Gtilt = gyro_absolute_tilt.name;                        % Posi��o angular em Z,Y,X absoluto (em rela��o aos eixos iniciais)
Mag = magnetometer.name;                          % Magnetometro
AcelMagTilt_name = acel_mag_tilt.name;                  % Posi��o angular em Z,Y,X absoluto, usando Acelera��o e magnetometro
CompTilt = comp_tilt.name;                     % Posi��o angular usando o filtro complementar
KalmanTilt_name = kalman_tilt.name;                   % Posi��o angular usando o filtro de kalman
MadgwickTilt_name = Madgwick_tilt.name;                 % Posi��o angular usando o filtro de madgwick
Acel_G = acel_without_g.name;                       % Acelera��o desconsiderando a gravidade (utilizando o melhor filtro p/ remove-la)
Quat = quaternion.name;                         % Plot com os valore de quaternion extraidos do filtro de madgwick
Car3DGdeg_name = car_3d_gdeg.name;                    % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (Gdeg)
Car3DGtilt_name = car_3d_gtilt.name;                   % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (Gtilt)
Car3DAcelMag_name = car_3d_acelMag.name;                 % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (AcelMagTilt_name)
Car3DComp_name = car_3d_comp.name;                    % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (CompTilt)
Car3DKalman_name = car_3d_kalman.name;                  % Posi��o angular atual usando um objeto 3D rotacionando utilizando matriz de Rota��o (KalmanTilt_name)
Car3DMadgwick_name = car_3d_madgwick.name;                % Posi��o angular atual usando um objeto 3D rotacionando utilizando quaternios advindos do filtro de Madgwick
Compass_name = compass.name;                      % Angulo de yaw estraido do magnetometro sem compensa��o de tilt plotado em plano polar
CompassCompensated_name = compass_compensated.name;           % Angulo de yaw estraido do magnetometro com compensa��o de tilt, usando dados do MPU, plotado em plano polar

%% PARAMETROS DE USU�RIO %%
% Fonte de leitura
read_from_serial=false;     % Set to false to use a file
serial_COM='COM4';
serial_baudrate=115200;
file_full_path='Dados/teste1.txt';

% Amostragem
max_size=4000;              % Quantidade maxima de amostras exibidas na tela
freq_sample=100;            % Frequencia da amostragem dos dados

% Plotagem
plot_in_real_time=true;     % Define se o plot ser� so no final, ou em tempo real
freq_render=5;              % Frequencia de atualiza��o do plot
layout= {...                % Layout dos plots, as visualiza��es poss�veis est�o variaveis no inicio do arquivo

    Car3DGdeg_name, Car3DGtilt_name, Car3DAcelMag_name ;...
    Car3DComp_name, Car3DKalman_name, Car3DMadgwick_name;...

};                          % OBS: Repita o nome no layout p/ expandir o plot em varios grids

% Constantes do sensor
const_g=9.8;                % Constante gravitacional segundo fabricante do MPU
gx_bias=-1.05;              % 
gy_bias=0.2;                % 
gz_bias=-0.52;              % 
ax_bias=0;                  % 
ay_bias=0;                  % 
az_bias=0.04;               % 
hx_offset=-70;              % 
hy_offset=228;              % 
hz_offset=10;               % 
hx_scale=1.020833;          % 
hy_scale=0.940048;          % 
hz_scale=1.045333;          % 


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

%% Define uma janela p/ plot
plot_1 = Render(freq_render, layout);

% Obtem a lista de itens unicos definidos no layout
% para evitar calculo de itens desceness�rios
setted_objects_name = plot_1.setted_objects_name;

aceleration.initialize(plot_1, max_size, window_k);
gyroscope.initialize(plot_1, max_size, window_k);
magnetometer.initialize(plot_1, max_size, window_k);
gyro_relative_tilt.initialize(plot_1, max_size);
gyro_absolute_tilt.initialize(plot_1, max_size);
acel_mag_tilt.initialize(plot_1, max_size);
comp_tilt.initialize(plot_1, max_size);
acel_without_g.initialize(plot_1, max_size);
velocity.initialize(plot_1, max_size);
position.initialize(plot_1, max_size);
kalman_tilt.initialize(plot_1, max_size, A,B,C,Q,R);
Madgwick_tilt.initialize(plot_1, max_size, freq_sample, beta);
quaternion.initialize(plot_1, max_size);
compass.initialize(plot_1);
compass_compensated.initialize(plot_1);
car_3d_gdeg.initialize(plot_1);
car_3d_gtilt.initialize(plot_1);
car_3d_acelMag.initialize(plot_1);
car_3d_comp.initialize(plot_1);
car_3d_kalman.initialize(plot_1);
car_3d_madgwick.initialize(plot_1);

%% Abre porta serial / arquivo
if read_from_serial
    reader = ReaderSerial(serial_COM, serial_baudrate);
else
    reader = ReaderFile(file_full_path);
end

%% Configura as vari�veis do MPU
esc_ac = str2int16(reader.metadatas.aesc_op);                   % Vem do Arduino, fun��o que configura escalas de Acelera��o
esc_giro = str2int16(reader.metadatas.gesc_op);                 % e giro //+/- 2g e +/-250gr/seg

%% Obtem os dados e plota em tempo real
% NOTA: Se o buffer do serial encher (> 512 bytes) o programa pode explodir ou apresentar erros, caso isso ocorra
% abaixe a taxa de renderiza��o do gr�fico. Para verificar se erros ocorreram, compare a quantidade de amostras enviadas com a quantidade lida
time_calc_data = 0;
count=0;                                % conta quantas amostras foram lidas
while true
    
    %% L� uma amostra de cada da porta serial/arquivo
    data = reader.read_sample();
    
    % Se � o fim do arquivo ou deu algum erro finaliza
    if isempty(data)
        break;
    end
    
    count=count+1;
    
    t1 = tic;
    data = str2int16(data);

    %% Convert data
    aceleration.calculate(data(1:3), [ax_bias, ay_bias, az_bias], esc_ac);
    gyroscope.calculate(data(4:6), [gx_bias, gy_bias, gz_bias], esc_giro);
    magnetometer.calculate(data(7:9), [hx_offset, hy_offset, hz_offset], [hx_scale, hy_scale, hz_scale]);

    aceleration.update();
    gyroscope.update();
    magnetometer.update();

    if isOneIn(setted_objects_name, {Gdeg, Gtilt, AcelMagTilt_name, CompTilt, Car3DGdeg_name, Car3DGtilt_name, Car3DAcelMag_name, Car3DComp_name, Acel_G, Vel, Space})
        gyro_relative_tilt.calculate(gyroscope.last(), gyroscope.penult(), freq_sample);
        gyro_relative_tilt.update();
    end
    
    if isOneIn(setted_objects_name, {Gtilt, CompTilt, Car3DGtilt_name, Car3DAcelMag_name, Car3DComp_name})
        gyro_absolute_tilt.calculate(gyro_relative_tilt.last());
        gyro_absolute_tilt.update();
    end
    
    if isOneIn(setted_objects_name, {AcelMagTilt_name, CompTilt, KalmanTilt_name, Acel_G, Vel, Space, Car3DAcelMag_name, Car3DKalman_name, Car3DComp_name, CompassCompensated_name})
        acel_mag_tilt.calculate(aceleration.last(), magnetometer.last());
        acel_mag_tilt.update();
    end

    if isOneIn(setted_objects_name, {Compass_name})
        compass.calculate(magnetometer.last());
        compass.update();
    end

    if isOneIn(setted_objects_name, {CompassCompensated_name})
        acel_mag_last = acel_mag_tilt.last();
        compass_compensated.calculate(acel_mag_last(3));
        compass_compensated.update();
    end

    if isOneIn(setted_objects_name, {CompTilt, Car3DComp_name})
        comp_tilt.calculate(gyro_relative_tilt.last(), gyro_relative_tilt.penult(), acel_mag_tilt.last(), mu); 
        comp_tilt.update();
    end

    if isOneIn(setted_objects_name, {KalmanTilt_name, Car3DKalman_name})
        kalman_tilt.calculate(gyroscope.last(), acel_mag_tilt.last());
        kalman_tilt.update();
    end
    
    if isOneIn(setted_objects_name, {MadgwickTilt_name, Car3DMadgwick_name, Quat})
        Madgwick_tilt.calculate(gyroscope.last(), aceleration.last(), magnetometer.last());
        Madgwick_tilt.update();
    end

    %% Plota quaterions do filtro de madgwick
    if isOneIn(setted_objects_name, {Quat})
        quaternion.calculate(Madgwick_tilt.last_quaternion());
        quaternion.update();
    end
    
    if isOneIn(setted_objects_name, {Acel_G, Vel, Space})
        acel_without_g.calculate(gyro_relative_tilt.last(), aceleration.last());
        acel_without_g.update();
    end

    if isOneIn(setted_objects_name, {Vel, Space})
        velocity.calculate(acel_without_g.last(), acel_without_g.penult(), freq_sample);
        velocity.update();
    end

    if isOneIn(setted_objects_name, {Space})
        position.calculate(velocity.last(), velocity.penult(), freq_sample);
        position.update();
    end

    %% Plota o carro em 3d, podendo ser usado qualquer um dos dados para rotacionar o objeto (Rota��o absoluta, relativa, filtro de kalman ...)
    if isOneIn(setted_objects_name, {Car3DGdeg_name})
        car_3d_gdeg.calculate(gyro_relative_tilt.last());
        car_3d_gdeg.update();
    end

    if isOneIn(setted_objects_name, {Car3DGtilt_name})
        car_3d_gtilt.calculate(gyro_absolute_tilt.last());
        car_3d_gtilt.update();
    end

    if isOneIn(setted_objects_name, {Car3DAcelMag_name})
        car_3d_acelMag.calculate(acel_mag_tilt.last());
        car_3d_acelMag.update();
    end

    if isOneIn(setted_objects_name, {Car3DComp_name})
        car_3d_comp.calculate(comp_tilt.last());
        car_3d_comp.update();
    end

    if isOneIn(setted_objects_name, {Car3DKalman_name})
        car_3d_kalman.calculate(kalman_tilt.last());
        car_3d_kalman.update();
    end

    if isOneIn(setted_objects_name, {Car3DMadgwick_name})
        car_3d_madgwick.calculate(Madgwick_tilt.last_quaternion());
        car_3d_madgwick.update();
    end
    
    time_calc_data = time_calc_data + toc(t1);

    %% Tenta redesenhar o plot, se deu o tempo da frequencia
    if plot_in_real_time
        plot_1.try_render();
    end
end

%% Renderiza pela ultima vez, independente de ter dado o tempo da frequencia
plot_1.force_render();

reader.delete();
plot_1.delete();

%% Calcula m�dia dos tempos
fprintf('Tempo m�dio de calculo: %fs\n', time_calc_data / count);

%% Aqui acaba o script
fprintf(1,'Recebidos %d amostras\n\n',count);
return;