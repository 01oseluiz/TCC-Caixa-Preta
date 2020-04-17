% Ler da porta serial
% Ainda precisa melhorar

clear all;
close all;

%Vem do Arduino, fun��o que configura escalas
%mpu_escalas(0,0);     //+/- 2g e +/-250gr/seg
esc_ac=2;
esc_giro=250;

% Abre porta serial
sid=serial('COM3','Baudrate',500000);
fopen(sid);

if (sid==-1)
    fprintf(1,'Nao abriu COM3.\n');
    return
end
fprintf(1,'Pronto para receber dados!\n');

% Aguarda o MPU inicializar (enviar -1 pela serial)
while true
    temp = fscanf(sid,'%s');
    if strcmp(temp,'start') == 1
        break;
    end
end
fprintf('Iniciando leitura.\n')

z=0;
cont=0;       % conta dados
x=[];

while true
    % Verifica se tem pelo menos 1 dado no buffer (5 caracteres)
    if sid.BytesAvailable < 5
        continue
    end
    
    z=fscanf(sid,'%s');
    
    if strcmp(z,'fim') == 1
        break;
    else
        z = str2num(z);
    end
    
    x=[x z];
    cont=cont+1;
end

fprintf(1,'Recebidos %d dados\nLeituras = %d.\n',cont,cont/7);
fclose(sid);

%Separar leituras, de 7 em 7
tot=floor(cont/7);
ax=zeros(1,tot);
ay=ax;
az=ax;
tp=ax;
gx=ax;
gy=ax;
gz=ax;
for ii=1:tot
    ax(1,ii) = x( 1, ((ii-1)*7)+1 );
    ay(1,ii) = x( 1, ((ii-1)*7)+2 );
    az(1,ii) = x( 1, ((ii-1)*7)+3 );
    tp(1,ii) = x( 1, ((ii-1)*7)+4 );
    gx(1,ii) = x( 1, ((ii-1)*7)+5 );
    gy(1,ii) = x( 1, ((ii-1)*7)+6 );
    gz(1,ii) = x( 1, ((ii-1)*7)+7 );
end

% Janela da media movel
mediamovel_k = 10;

% Converter acelera��es em "g"
ax=mediamovel(esc_ac*(ax/32767), mediamovel_k);
ay=mediamovel(esc_ac*(ay/32767), mediamovel_k);
az=mediamovel(esc_ac*(az/32767), mediamovel_k);

% Converter giros em "graus/seg"
gx=mediamovel(esc_giro*(gx/32767), mediamovel_k);
gy=mediamovel(esc_giro*(gy/32767), mediamovel_k);
gz=mediamovel(esc_giro*(gz/32767), mediamovel_k);

% Converter temperatura para Celsius
tp=(tp/340)+36.53;

% Desenhar gr�ficos
% Define a janela p/ acelara��o e giro
f1 = figure('Units', 'normalized', 'Position', [0, 0, 1, 1]);

% variaveis p/ normalizar os eixos de giro e acelera��o
max_acel = max([ax, ay, az]);
min_acel = min([ax, ay, az]);
y_lim_acel = [min_acel, max_acel];
max_giro = max([gx, gy, gz]);
min_giro = min([gx, gy, gz]);
y_lim_giro = [min_giro, max_giro];

%ax
figure(f1);
subplot(2,3,1);
plot(ax);
ylim(y_lim_acel)
grid;
title('Acelera��o: eixo X em g');
xlabel('Amostra');
ylabel('g');

%ay
subplot(2,3,2);
plot(ay);
ylim(y_lim_acel)
grid;
title('Acelera��o: eixo Y em g');
xlabel('Amostra');
ylabel('g');

%az
subplot(2,3,3);
plot(az);
ylim(y_lim_acel)
grid;
title('Acelera��o: eixo Z em g');
xlabel('Amostra');
ylabel('g');

%gx
subplot(2,3,4);
plot(gx);
ylim(y_lim_giro)
grid;
title('Giro: eixo X em graus/seg');
xlabel('Amostra');
ylabel('graus/seg');

%gy
subplot(2,3,5);
plot(gy);
ylim(y_lim_giro)
grid;
title('Giro: eixo Y em graus/seg');
xlabel('Amostra');
ylabel('graus/seg');

%gz
subplot(2,3,6);
plot(gz);
ylim(y_lim_giro)
grid;
title('Giro: eixo Z em graus/seg');
xlabel('Amostra');
ylabel('graus/seg');

%Aqui acaba o script
return;

%Temperatura
figure(2);
plot(tp);
grid;
title('Temperatura em graus Celsius');
xlabel('Amostra');
ylabel('graus Celsius');

