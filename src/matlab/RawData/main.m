% Ler da porta serial
% Ainda precisa melhorar

clear all;
fclose(instrfind);  %Fechar poss�vel porta serial
close all;


%%%%%%%%%%%%%%%%%%%%%% PARAMETROS DE USU�RIO %%%%%%%%%%%%%%%%%%%%%%%%%
% Fonte de leitura
read_from_serial=true;      % Set to false to use a file
serial_COM='COM3';          %
serial_baudrate=115200;     %
file_full_path='';          %
file_simulated_freq=100;    % Simulate a pulling frequence, e.g.: to simulate an freq of 100 samples per second use 100hz

% Amostragem
max_size=2000;              % Quantidade maxima de amostras exibidas na tela
freq_sample=100;            % Frequencia da amostragem dos dados

% Media movel parametros 
window_k = 10;              % Janela da media movel (minimo = 2)

% Plotagem
freq_render=5;              % Frequencia de atualiza��o do plot
layout= {...                % Layout dos plots, as visualiza��es poss�veis s�o:
    '' '' '' '' '' '';...   % Acel, Vel, Space
    '' '' '' '' '' '';...   % Gvel, Gdeg, Gtilt 
    '' '' '' '' '' '';...   % Mag, FusionTilt
    '' '' '' '' '' '';...   % CompTilt, KalmanTilt, MadgwickTilt
    '' '' '' '' '' '';...   % Space3D, Tilt3D
};                          % OBS: Repita o nome no layout p/ expandir o plot em varios grids

mu=0.02;                    % Vari�vel de ajuste do filtro complementar

% Constantes do sensor
const_g=9.8;                % Constante gravitacional segundo fabricante do MPU
gx_bias=0.80;               % 
gy_bias=0.77;               % 
gz_bias=0.45;               % 
ax_bias=0.0325;             % 
az_bias=0.035;              % 
ay_bias=0.07;               % 
esc_ac=2;                   % Vem do Arduino, fun��o que configura escalas de acelera��o
esc_giro=250;               % e giro //+/- 2g e +/-250gr/seg
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Par�metros
cont=0;                     % Conta quantas amostras foram lidas

% Abre porta serial
sid=serial('COM3','Baudrate',115200);
fopen(sid);

if (sid==-1)
    fprintf(1,'Nao abriu COM3.\n');
    return
end
fprintf('Pronto para receber dados!\n');
fprintf('Por favor, selecione Teste 12 na Caixa Preta.\n');

% Aguarda o MPU inicializar (enviar -1 pela serial)
while true
    temp = fscanf(sid,'%s');
    if strcmp(temp,'start') == 1
        break;
    end
    fprintf('%s\n', temp);
end
fprintf('Iniciando leitura.\n');

% Vari�veis de dados
ax=zeros(1,max_size);                   % Acelera��o eixo X
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
R=[[1,0,0];[0,1,0];[0,0,1]];            % Matriz de rota��o que move o corpo da posi��o inicial p/ a atual
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
compl_Roll=zeros(1,max_size);           % Movimento de Roll usando filtro complementar
compl_Pitch=zeros(1,max_size);          % Movimento de Pitch usando filtro complementar
compl_Yaw=zeros(1,max_size);            % Movimento de Yaw usando filtro complementar
t = 0:max_size;                         % Eixo temporal do gr�fico

% Define a janela p/ plot
f1 = figure('units','normalized','outerposition',[0 0 1 1]);

% Desenhar gr�ficos
%Plota acelera��o
figure(f1);
subplot(3,4,1);
p_ax = plot(ax, 'r');
grid;
title('Acelera��o em g');
xlabel('Amostra');
ylabel('g');
hold on
p_ay = plot(ay, 'g');
p_az = plot(az, 'b');
legend('aX', 'aY', 'aZ');
hold off

%Plota velocidade
subplot(3,4,2);
grid;
title('Velocidade em m/s');
xlabel('Amostra');
ylabel('m/s');

%Plota espaco
subplot(3,4,3);
grid;
title('Posi��o em metros');
xlabel('Amostra');
ylabel('metros');

%Plota giro/s
subplot(3,4,5);
p_gx = plot(gx, 'r');
grid;
title('Giro em graus/seg');
xlabel('Amostra');
ylabel('graus/seg');
hold on
p_gy = plot(gy, 'g');
p_gz = plot(gz, 'b');
legend('gX', 'gY', 'gZ');
hold off

%Plota giro (relativo) em graus usando giro/s
subplot(3,4,6);
p_gRoll = plot(gRoll, 'r');
grid;
title('Giro em graus(relativo)');
xlabel('Amostra');
ylabel('graus');
hold on
p_gPitch = plot(gPitch, 'g');
p_gYaw = plot(gYaw, 'b');
legend('Roll', 'Pitch', 'Yaw');
hold off

%Plota giro (absoluto) em graus usando giro/s + rota��o matricial
subplot(3,4,7);
p_gRoll_abs = plot(gRoll_abs, 'r');
grid;
title('Giro em graus(absoluto)');
xlabel('Amostra');
ylabel('graus');
hold on
p_gPitch_abs = plot(gPitch_abs, 'g');
p_gYaw_abs = plot(gYaw_abs, 'b');
legend('Roll', 'Pitch', 'Yaw');
hold off

%Plota giro (absoluto) em graus usando acelera��o e magnetometro
subplot(3,4,11);
p_aRoll = plot(aRoll, 'r');
grid;
title('Giro em graus(absoluto) usando acel + mag');
xlabel('Amostra');
ylabel('graus');
hold on
p_aPitch = plot(aPitch, 'g');
legend('aRoll', 'aPitch');
hold off

%Plota giro (absoluto) em graus filtro complementar
subplot(3,4,4);
p_compl_roll = plot(compl_Roll, 'r');
grid;
title('Filtro complementar');
xlabel('Amostra');
ylabel('graus');
hold on
p_compl_pitch = plot(compl_Pitch, 'g');
p_compl_yaw = plot(compl_Yaw, 'b');
legend('Roll', 'Pitch', 'Yaw');
hold off

p_ax.YDataSource = 'ax';
p_ay.YDataSource = 'ay';
p_az.YDataSource = 'az';
p_gx.YDataSource = 'gx';
p_gy.YDataSource = 'gy';
p_gz.YDataSource = 'gz';
p_gPitch.YDataSource = 'gPitch';
p_gRoll.YDataSource = 'gRoll';
p_gYaw.YDataSource = 'gYaw';
p_aPitch.YDataSource = 'aPitch';
p_aRoll.YDataSource = 'aRoll';
p_gRoll_abs.YDataSource = 'gRoll_abs';
p_gPitch_abs.YDataSource = 'gPitch_abs';
p_gYaw_abs.YDataSource = 'gYaw_abs';
p_compl_roll.YDataSource = 'compl_Roll';
p_compl_pitch.YDataSource = 'compl_Pitch';
p_compl_yaw.YDataSource = 'compl_Yaw';

% Obtem os dados e plota em tempo real
% NOTA: Se o buffer do serial encher (> 512 bytes) o programa explode, caso isso ocorra
% abaixe a taxa de renderiza��o do grafico
time = now;
while true
    
    % L� at� achar quebra de linha
    data=fscanf(sid,'%s');
    
    % Checa se n�o � o final da transmiss�o
    if ~isempty(strfind(data,'fim'))
        break;
    end

    % Quebra a string no marcador ';'
    data=strsplit(data,';');

    % Checa se realmente leu todos os dados
    if length(data) < 7
        continue
    end

    cont=cont+1;
    
    data = str2double(data);
    
    % Converter acelera��es em "g"
    data(1)=esc_ac*(data(1)/32767) - ax_bias;
    data(2)=esc_ac*(data(2)/32767) - ay_bias;
    data(3)=esc_ac*(data(3)/32767) - az_bias;

    % Converter giros em "graus/seg"
    data(5)=esc_giro*(data(5)/32767) - gx_bias;
    data(6)=esc_giro*(data(6)/32767) - gy_bias;
    data(7)=esc_giro*(data(7)/32767) - gz_bias;

    % Converter temperatura para Celsius
    data(4)=(data(4)/340)+36.53;

    % Salva os dados sem altera��o p/ poder aplicar a media movel mais a frente
    r_data = [r_data(2:window_k,:) ; data(1:7)];

    % Faz a media movel dos dados lidos
    data = sum(r_data) / window_k;
    
    % Salva valores ap�s aplicar a media movel
    ax = [ax(2:max_size) data(1)];
    ay = [ay(2:max_size) data(2)];
    az = [az(2:max_size) data(3)];
    tp = [tp(2:max_size) data(4)];
    gx = [gx(2:max_size) data(5)];
    gy = [gy(2:max_size) data(6)];
    gz = [gz(2:max_size) data(7)];

    % Calcula Yaw, Pitch e Roll realtivos(em rela��o a ultima rota��o do corpo) p/ a nova amostra usando giro
    % Usando o giro, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)
    newPitch = (gPitch(max_size) + ((gy(max_size-1) + gy(max_size)) / (2 * freq_sample) ));
    newRoll = (gRoll(max_size) + ((gx(max_size-1) + gx(max_size)) / (2 * freq_sample) ));
    newYaw = (gYaw(max_size) + ((gz(max_size-1) + gz(max_size)) / (2 * freq_sample) ));
    
    gPitch  = [gPitch(2:max_size) newPitch];
    gRoll   = [gRoll(2:max_size)  newRoll];
    gYaw    = [gYaw(2:max_size)   newYaw];
    
    % Calcula a matriz de rota��o (X,Y,Z) que foi respons�vel por mover o corpo da posi��o da amostra anterior para a atual
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
    R = R * temp_R;
    

    % Extrai Yaw, Pitch e Roll absolutos(em rela��o a posi��o inicial do corpo) p/ a nova amostra usando a atual matriz de rota��o (X,Y,Z)
    newRoll = atan2(R(3,2), R(3,3)) * 180/pi;
    newYaw = atan2(R(2,1), R(1,1)) * 180/pi;
    if cosd(newYaw) == 0
        newPitch = atan2(-R(3,1), R(2,1)/sind(newYaw)) * 180/pi;
    else
        newPitch = atan2(-R(3,1), R(1,1)/cosd(newYaw)) * 180/pi;
    end

    gPitch_abs = [gPitch_abs(2:max_size) newPitch];
    gRoll_abs = [gRoll_abs(2:max_size) newRoll];
    gYaw_abs = [gYaw_abs(2:max_size) newYaw];
    
    % Calcula Yaw, Pitch e Roll absolutos(em rela��o a posi��o inicial do corpo) p/ a nova amostra usando acelera��o
    % Usando a acelera��o, usamos o vetor de gravidade que deve sempre
    % estar presente p/ determinar a posi��o do corpo
    % assim temos que p/ a order de rota��o X,Y,Z
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

    % Calcula rota��o usando filtro complementar
    newRoll = (1-mu)*(compl_Roll(max_size) + delta_gRoll) + mu*aRoll(max_size);
    newPitch = (1-mu)*(compl_Pitch(max_size) + delta_gPitch) + mu*aPitch(max_size);
    % newYaw = 

    compl_Roll = [compl_Roll(2:max_size) newRoll];
    compl_Pitch = [compl_Pitch(2:max_size) newPitch];
    % compl_Yaw = [compl_Yaw(2:max_size) newYaw]
    
    % Calcula a acelera��o removendo a gravidade
    % Obtem o vetor gravidade atual rotacionando em sentido contr�rio realizado pelo corpo, considerando gravidade = 1g
    gravity_vector =   [-sind(gPitch(max_size)),...
                         cosd(gPitch(max_size))*sind(gRoll(max_size)),...
                         cosd(gPitch(max_size))*cosd(gRoll(max_size))
                       ];
    ax_without_gravity = [ax_without_gravity(2:max_size) (ax(max_size) - gravity_vector(1))];
    ay_without_gravity = [ay_without_gravity(2:max_size) (ay(max_size) - gravity_vector(2))];
    az_without_gravity = [az_without_gravity(2:max_size) (az(max_size) - gravity_vector(3))];
    
    %ax = ax_without_gravity;
    %ay = ay_without_gravity;
    %az = az_without_gravity;
    
    % Re plota
    if (now-time)*100000 > 1/freq_render
        refreshdata
        drawnow
        time = now;
    end
end

%Aqui acaba o script
fprintf(1,'Recebidos %d amostras\n\n',cont);
fclose(sid);
return;