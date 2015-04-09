function [tester]=test_strategy(name,interval,starttime,endtime,strat,ifintraday,ifpal)

    % load historical data
    disp('loading historical data...');
    
    prices=loaddata2(name, interval,starttime,endtime);
    %load prices;
    %load sp1index;
    %prices=sp1index;
    [~,I]=sort(prices(:,1),1,'descend');
    prices=prices(I,:);
    
    [prices,e1,e2,e3,e4,e5,~,~]=findabnormal(prices);
    error=zeros(5,1);
    
    error(1)=size(e1,1);
    error(2)=size(e2,1);
    error(3)=size(e3,1);
    error(4)=size(e4,1);
    error(5)=size(e5,1);
    
    if size(prices,1)<=1 && interval==-1
        disp('Cannot find data in database, trying yahoo finance....');
        try
            prices=fetch(yahoo,name,starttime,endtime);
        catch
            disp('Cannot find data in yahoo, trying google finance....');
            prices=getgoogledata(name,starttime,endtime);
        end
    end    

    % initialize backtesting tool
    capital=prices(end,2);
    tester=backtester(capital,strat,size(prices,1),ifintraday);

    disp('starting backtesting...');
    if ~ifpal
        h=waitbar(0,'Calculating backtest data...');
        for i=1:size(prices,1)
            datafeed=prices(end-i+1,:);
            tester=feed(tester,datafeed);
            if ~ifpal
                waitbar(i/size(prices,1),h,'Calculating backtest data...');
            end
            %disp(num2str(i/size(prices,1)*100));
        end
        close(h);
    else
        for i=1:size(prices,1)
            datafeed=prices(end-i+1,:);
            tester=tester.feed(tester,datafeed);
            %disp(num2str(i/size(prices,1)*100));
        end
    end


    disp('backtest finished, generating report...');

    % reporting
    %plot(tester.trades(:,5));
    tester=tester.reporting_pdf([name '_' num2str(interval) 'min'],error,interval,1);
    if interval>0
        tester.writeToDatabase(name,strat.strat_name,interval,[name '-' num2str(interval) 'min']);
    else
        tester.writeToDatabase(name,strat.strat_name,interval,[name ' daily']);
    end
end