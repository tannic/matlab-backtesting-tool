clear all;
clc;


name='gx1 index';
%strat=candleknnstrat(name,'1990-1-1','2000-3-1',-1,0.002,-0.002,50);
%strat=rsilbs();
interval=-1;

%names={'EWY', 'EWD', 'EWC', 'EWQ', 'EWU', 'EWA', 'EWP', 'EWH', 'EWL', 'EFA', 'EPP', 'EWM', 'EWI', 'EWG', 'EWO', 'IWM', 'QQQ', 'EWS', 'EWT', 'EWJ'};
names={};

refs=cell(size(names,2),1);

parfor i=1:size(names,2)
    prices=loaddata2(names{i},interval,'1990-1-1','2014-12-1');
    [~,I]=sort(prices(:,1),1);
    prices=prices(I,:);
    
    refs{i}=prices;
end



for i=1:1
    for j=1:1
        %strat=hangingmanstrat();
        strat=candleknnstrat(refs,2000,50,0.001,-0.005,3,i);
        starttime='1990-1-1';
        endtime='2014-12-4';

        t=test_strategy(name,interval,starttime,endtime,strat,0,0);
        figure
        plot([t.his_equity t.hisdata(:,5)]);
    end
end