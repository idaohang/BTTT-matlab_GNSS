function [smQM] = dopplerSM(nowQM, WW, EphGlo)

% function [smQM] = dopplerSM(nowQM, WW)
% function [smQM] = dopplerSM(nowQM, WW, EphGlo)
%
% Do : 실시간 도플러-스무딩
%
% input:
%       nowQM  : 핸재 epoch의 모든데이터(C1,D1 필히있어야함)
%       WW     : window-width
%       EphGlo : (Glonass System을 포함할 경우에는 넣어주어야 안전함,
%                   Glonass System을 포함하지 않는다면 넣어주지 않아도 무방)
% output:
%       smQM   : 현재 epoch의 (도플러-스무딩을 적용한)C1데이터
%
% Copyright: taeil Kim, January 20, 2015@INHA University
%  1.28.2015 : PAST_QM 전역변수로 수정 (프로그램 시작/종료에서 clear -global)
%  2. 3.2015 : GPS외 모든위성 적용 가능하도록 수정
%  3. 4.2015 : getFrequency_Band1 추가 (각 신호의 주파수를 올바르게 적용)
%              GSP / GLONASS / B
%  7. 7.2015 : GLONASS Frequency Channel Number를 외부에서 받아오도록 수정
%              (파라미터 EphGlo 추가)

% % clc; clear all;
% % 
% % nowQM = [365459,302,320,23066245.1690000;365459,302,311,123225061.520000;365459,302,331,2901.35300000000;365459,302,341,47;365459,124,120,23045068.2660000;365459,124,111,121239715.537000;365459,124,131,4042.45500000000;365459,124,141,44;365459,113,120,20390725.9060000;365459,113,111,107291043.328000;365459,113,131,-931.438000000000;365459,113,141,48;365459,102,120,23905157.4070000;365459,102,111,125759513.549000;365459,102,131,-3318.38400000000;365459,102,141,44;365459,120,120,20156156.2400000;365459,120,111,106058369.393000;365459,120,131,1345.38800000000;365459,120,141,48;365459,121,120,22947393.0970000;365459,121,111,120726411.760000;365459,121,131,2788.75200000000;365459,121,141,47;365459,323,320,22304470.4190000;365459,323,311,119453418.746000;365459,323,331,-3777.82300000000;365459,323,341,40;365459,130,120,24048501.4000000;365459,130,111,126512776.351000;365459,130,131,-2249.80700000000;365459,130,141,46;365459,310,320,21088029.1210000;365459,310,311,112550097.917000;365459,310,331,524.854000000000;365459,310,341,45;365459,118,120,24411940.3310000;365459,118,111,128422655.293000;365459,118,131,2994.25500000000;365459,118,141,41;365459,308,320,21041811.4300000;365459,308,311,112817622.588000;365459,308,331,-1359.46400000000;365459,308,341,50;365459,317,320,22283963.5400000;365459,317,311,119385592.267000;365459,317,331,2595.07300000000;365459,317,341,45;365459,105,120,21723852.7580000;365459,105,111,114296679.539000;365459,105,131,-1538.68400000000;365459,105,141,44;365459,309,320,24303733.1870000;365459,309,331,-2842.00400000000;365459,309,341,26;365459,115,120,20238107.0690000;365459,115,111,106489021.337000;365459,115,131,997.604000000000;365459,115,141,48;365459,311,320,21576106.0570000;365459,311,311,115435522.864000;365459,311,331,3819.00500000000;365459,311,341,46;365459,301,320,20058068.6840000;365459,301,311,107361323.118000;365459,301,331,1003.51300000000;365459,301,341,40;365459,324,320,20679027.2020000;365459,324,311,110719535.073000;365459,324,331,-1260.83800000000;365459,324,341,45;365459,129,120,23608377.1390000;365459,129,111,124199932.594000;365459,129,131,-2289.34700000000;365459,129,141,44;365459,104,120,21740231.5850000;365459,104,111,114382734.936000;365459,104,131,-2092.60500000000;365459,104,141,50];
% % WW = 5;
% EphGlo = ReadEPH_GLO('brdc3360.16g');

%% Function
getPrn      = @(prn_) mod(prn_, 100);
getSystem   = @(prn_) floor(prn_./100);
%% 초기 설정
global PAST_QM;     % ww 전 에폭까지 C1,D1을 전역변수로 저장해둠( 1.28.2015)
CCC = 299792458.;   %: CCC = Speed of Light [m/s]
Type_C1 = 20;       % mod ( C1, 100 )
Type_D1 = 31;       % mod ( D1, 100 )
if nargin < 3, EphGlo=[]; end
                    % GLONASS를 쓰지않는 System에서도 사용 가능하도록 함
%% 위성별 구분을 위해 데이터 수정( 2. 3.2015)
SVs = floor( nowQM(:,3)./100 );
nowQM(:,2) = nowQM(:,2) + SVs*100;              % prn 구분
nowQM(:,3) = nowQM(:,3) - SVs*100;              % obs type 통일
%% 데이터 정리
epoch = nowQM(1,1);                             % 들어온 데이터의 에폭
prs = SelectQM(nowQM, Type_C1);                 % C1 데이터만 분리
dps = SelectQM(nowQM, Type_D1);                 % D1 데이터만 분리
prns= prs(:,2);                                 % 현재 데이터의 prn들
%% CODE
if isempty(PAST_QM)
    %--- 첫 데이터는 도플러-스무딩 하지않음 ---------------------------------
    smQM  = prs;
else
    %--- 2번째 데이터 이상 도플러-스무딩 실시 -------------------------------
    smQM  = [];
    idx = logical(PAST_QM(:,1) >= epoch-WW);
    PAST_QM = PAST_QM(idx,:);                   % ww보다 벗어난 에폭 삭제
    for p=prns'                                 % prn별로 계산 시작
        QM_past= SelectQM2(PAST_QM, p, Type_C1, Type_D1);
        QM_now = SelectQM2(nowQM, p, Type_C1, Type_D1);
                                                % C1, D1같은 epoch끼리 묶음
        if isempty(QM_past)                     % 해당 prn의 첫등장
            p_sm= QM_now(3);
        else
            temp= [QM_past; QM_now];
            %--- prediction stage -----------------------------------------
            intg= cumtrapz(temp(:,1),temp(:,4));% cumtrapz(수치적분:사다리꼴)
            WL1 = CCC/getFrequency_Band1(getSystem(p),getPrn(p), EphGlo);
            pbar= mean( temp(:,3) + WL1*intg );
            %--- filtering stage ------------------------------------------
            p_sm= pbar - WL1*intg(end);
        end
        smQM = [smQM; epoch p Type_C1 p_sm];
    end
end
PAST_QM = [PAST_QM; prs; dps];
%% 데이터 복구( 2. 3.2015)
SVs = floor( smQM(:,2)./100 );
% SVs = SVs/2;
smQM(:,2) = smQM(:,2) - SVs*100;
smQM(:,3) = smQM(:,3) + SVs*100;
% end
%%
function f = getFrequency_Band1(system, prn, EphGlo)
% FCN(Frequency Channel Number) :: 2015.03.04 기준 데이터임
% SYSTEM_GPS = 1;
% SYSTEM_BDS = 3;     % 수정해야함(2015.02.09 순서바꿈)
% SYSTEM_GLO = 2;     % 수정해야함(2015.02.09 순서바꿈)
SYSTEM_GPS = 1;
SYSTEM_BDS = 2;     % 수정해야함(2015.02.09 순서바꿈)
SYSTEM_GLO = 3;     % 수정해야함(2015.02.09 순서바꿈)
% FCN=[1;-4;5;6;1;-4;5;6;-2;-7;0;-1;-2;-7;0;-1;-6;-3;3;2;4;-3;3;2;-5;];
FCN=[1;-4;5;6;1;-4;5;6;-6;-7;0;-1;-2;-7;0;-1;4;-3;3;2;4;-3;3;2];
switch system
    case SYSTEM_GPS
        f = 1575.42e6;
    case SYSTEM_BDS
        f = 1589.74e6;
    case SYSTEM_GLO
        try
            prnIdx = find(EphGlo(:,1)==prn);
            f = (1602 + EphGlo(prnIdx(1), 16) * 0.5625) * 1e6;
        catch % EphGlo=[]일 때, 즉 nargin < 3일 때(EphGlo 미입력시) 발생
            f = (1602 + FCN(prn-100) * 0.5625) * 1e6;   % FCN값 변경에 불안전
        end
    otherwise
        error('');
end
% end