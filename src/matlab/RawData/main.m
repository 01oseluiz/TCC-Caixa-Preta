% Ler da porta serial
% Ainda precisa melhorar
% BUGS:
% - file_simulated_freq ainda n�o funciona muito bem

addpath('quaternion_library');      % include quaternion library
addpath('reader');                  % include reader library
addpath('helpers');                 % include some useful functions
addpath('charts');                  % 
addpath('plots');                   % include plot library

close all;                          % close all figures
clear;                              % clear all variables
clc;                                % clear the command terminal

% Inst�ncia os plots
Vazio = '';                         % Deixa a celula vazia
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
plot_in_real_time=false;     % Define se o plot ser� so no final, ou em tempo real
freq_render=5;              % Frequencia de atualiza��o do plot
layout= {...                % Layout dos plots, as visualiza��es poss�veis est�o variaveis no inicio do arquivo

    aceleration, gyroscope, magnetometer, gyro_relative_tilt, gyro_absolute_tilt;...
    acel_mag_tilt, comp_tilt, acel_without_g, velocity, position;...
    kalman_tilt, Madgwick_tilt, quaternion, compass_compensated, car_3d_gdeg;...
    car_3d_gtilt, car_3d_acelMag, car_3d_comp, car_3d_kalman, car_3d_madgwick;...

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
setted_objects_id = plot_1.setted_objects_id;

%TODO - remover os initilize, isso deve fazer parte do construtor
aceleration.initialize(max_size, window_k);
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

%TODO - criar car3DQuaternios e car3DEuler:
% assim ao construir o objeto � injetado algum gr�fico q retorne eulers ou quaternios.
% O t�tulo do gr�fico deve mudar para apontar qual classe foi injetada nele
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


    if isOneIn(setted_objects_id, {gyro_relative_tilt.id, gyro_absolute_tilt.id, acel_mag_tilt.id, comp_tilt.id, car_3d_gdeg.id, car_3d_gtilt.id, car_3d_acelMag.id, car_3d_comp.id, acel_without_g.id, velocity.id, position.id})
        gyro_relative_tilt.calculate(gyroscope.last(), gyroscope.penult(), freq_sample);
    end
    
    if isOneIn(setted_objects_id, {gyro_absolute_tilt.id, comp_tilt.id, car_3d_gtilt.id, car_3d_acelMag.id, car_3d_comp.id})
        gyro_absolute_tilt.calculate(gyro_relative_tilt.last());
    end
    
    if isOneIn(setted_objects_id, {acel_mag_tilt.id, comp_tilt.id, kalman_tilt.id, acel_without_g.id, velocity.id, position.id, car_3d_acelMag.id, car_3d_kalman.id, car_3d_comp.id, compass_compensated.id})
        acel_mag_tilt.calculate(aceleration.last(), magnetometer.last());
    end

    if isOneIn(setted_objects_id, {compass.id})
        compass.calculate(magnetometer.last());
    end

    if isOneIn(setted_objects_id, {compass_compensated.id})
        acel_mag_last = acel_mag_tilt.last();
        compass_compensated.calculate(acel_mag_last(3));
    end

    if isOneIn(setted_objects_id, {comp_tilt.id, car_3d_comp.id})
        comp_tilt.calculate(gyro_relative_tilt.last(), gyro_relative_tilt.penult(), acel_mag_tilt.last(), mu); 
    end

    if isOneIn(setted_objects_id, {kalman_tilt.id, car_3d_kalman.id})
        kalman_tilt.calculate(gyroscope.last(), acel_mag_tilt.last());
    end
    
    if isOneIn(setted_objects_id, {Madgwick_tilt.id, car_3d_madgwick.id, quaternion.id})
        Madgwick_tilt.calculate(gyroscope.last(), aceleration.last(), magnetometer.last());
    end

    %% Plota quaterions do filtro de madgwick
    if isOneIn(setted_objects_id, {quaternion.id})
        quaternion.calculate(Madgwick_tilt.last_quaternion());
    end
    
    if isOneIn(setted_objects_id, {acel_without_g.id, velocity.id, position.id})
        acel_without_g.calculate(gyro_relative_tilt.last(), aceleration.last());
    end

    if isOneIn(setted_objects_id, {velocity.id, position.id})
        velocity.calculate(acel_without_g.last(), acel_without_g.penult(), freq_sample);
    end

    if isOneIn(setted_objects_id, {position.id})
        position.calculate(velocity.last(), velocity.penult(), freq_sample);
    end

    % %% Plota o carro em 3d, podendo ser usado qualquer um dos dados para rotacionar o objeto (Rota��o absoluta, relativa, filtro de kalman ...)
    if isOneIn(setted_objects_id, {car_3d_gdeg.id})
        car_3d_gdeg.calculate(gyro_relative_tilt.last());
    end

    if isOneIn(setted_objects_id, {car_3d_gtilt.id})
        car_3d_gtilt.calculate(gyro_absolute_tilt.last());
    end

    if isOneIn(setted_objects_id, {car_3d_acelMag.id})
        car_3d_acelMag.calculate(acel_mag_tilt.last());
    end

    if isOneIn(setted_objects_id, {car_3d_comp.id})
        car_3d_comp.calculate(comp_tilt.last());
    end

    if isOneIn(setted_objects_id, {car_3d_kalman.id})
        car_3d_kalman.calculate(kalman_tilt.last());
    end

    if isOneIn(setted_objects_id, {car_3d_madgwick.id})
        car_3d_madgwick.calculate(Madgwick_tilt.last_quaternion());
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