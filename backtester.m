classdef backtester
    
    properties
        ifintraday
        
        % time size price
        position
        
        initial_capital
        his_capital
        
        his_equity
              
        % open_time end_time open_price end_price size win/loss
        trades
                
        middleware
        
        cur_num
        
        transactions
        
        hisdata
        
        pday
        
        pp
    end
    
    methods
        function obj=backtester(init_c,strategy,total_bar_num,ifintraday)
            obj.position=[];
            
            obj.initial_capital=init_c;
            obj.his_capital=zeros(total_bar_num,1);
            obj.his_capital(1)=init_c;
            obj.his_equity=zeros(total_bar_num,1);
                  
            obj.trades=[];
                                    
            obj.cur_num=1;
            
            obj.transactions=[];
            obj.hisdata=[];
            
            obj.middleware=backtest_middleware(strategy);
            
            obj.pday=0;
            
            obj.ifintraday=ifintraday;
            obj.pp=0;
        end
        
        function obj=feed(obj,datafeed)
            
           
            if obj.ifintraday && (obj.pday==0 || obj.pday<floor(datafeed(:,1)))
                obj=obj.finalclearing();
                obj.pday=floor(datafeed(:,1));
                obj.middleware.orderbook=[];
                %m=obj.middleware.orderbook
            end          
            

            
            if obj.cur_num>1
                [signals,obj.middleware]=obj.middleware.feed(datafeed,obj.position,obj.his_capital(obj.cur_num-1),obj.hisdata);
                obj.his_capital(obj.cur_num)=obj.his_capital(obj.cur_num-1);
            else
                [signals,obj.middleware]=obj.middleware.feed(datafeed,obj.position,obj.his_capital(1),obj.hisdata);
            end
            
                        
            if size(signals,1)~=0
                for i=1:size(signals,1)
                    s=signals(i,:);
                    if s(1)==1
                        obj=obj.buy(s(3),s(2),datafeed(1));
                    else
                        obj=obj.sell(s(3),s(2),datafeed(1));
                    end
                end
            end
            
            if obj.cur_num>1
                [obj.middleware]=obj.middleware.feed2(datafeed,obj.position,obj.his_capital(obj.cur_num-1),obj.hisdata);
            else
                [obj.middleware]=obj.middleware.feed2(datafeed,obj.position,obj.his_capital(1),obj.hisdata);
            end
            
                          
            % calulate equity
            if size(obj.position,1)>0
                p=sum(obj.position(:,2));
                obj=obj.pairtrade();
            else
                p=0;
            end
            
            obj.his_equity(obj.cur_num)=obj.his_capital(obj.cur_num)+p*datafeed(:,5);
            
            obj.cur_num=obj.cur_num+1;
            
            obj.hisdata(end+1,:)=datafeed;
            
            
            
            %p=obj.position
        end
             
        function obj=sell(obj,price,lot,time)
            price=slipage(price,0);
            c=brokage(lot,0);
            price=price-c/lot;
            
            obj.position(end+1,:)=[time,-lot,price];

            %psell=obj.position
            obj.his_capital(obj.cur_num)=obj.his_capital(obj.cur_num)+price*lot;

            obj.transactions(end+1,:)=[time,-1,price,lot];
        end
        
        function obj=buy(obj,price,lot,time)
            
            price=slipage(price,1);
            
            maxlot=floor(obj.his_capital(obj.cur_num-1)/price);
            if lot>maxlot
                %lot=maxlot;
            end
            
            c=brokage(lot,1);
            
            if lot~=0
                price=price+c/lot;
            end
            
            obj.position(end+1,:)=[time,lot,price];
            %lot
            %pbuy=obj.position(:,2)
            obj.his_capital(obj.cur_num)=obj.his_capital(obj.cur_num)-price*lot;

            obj.transactions(end+1,:)=[time,1,price,lot];
        end
        
        function obj=pairtrade(obj)
            p=obj.position;
            [p,obj]=pairtrades(obj,p); 
            obj.position=p;
        end
        
        function [gross_profit,gross_loss]=getgrosspl(obj)
            profit_trades=obj.trades(obj.trades(:,6)>=0,:);
            loss_trades=obj.trades(obj.trades(:,6)<0,:);
            gross_profit=sum(profit_trades(:,6));
            gross_loss=sum(loss_trades(:,6));
        end
        
        function [wintrades,losstrades,winconc,lossconc,avgwin,avgloss,win,loss]=gettradesinfo(obj)
            profit_trades=obj.trades(obj.trades(:,6)>=0,:);
            loss_trades=obj.trades(obj.trades(:,6)<0,:);
            wintrades=size(profit_trades,1);
            losstrades=size(loss_trades,1);
            
            x=obj.trades(:,6)>=0;   
            winconc=max( diff( [0 (find( ~ (x' > 0) ) ) numel(x') + 1] ) - 1);
            
            x=obj.trades(:,6)<0;
            lossconc=max( diff( [0 (find( ~ (x' > 0) ) ) numel(x') + 1] ) - 1);
            
            avgwin=mean(profit_trades(:,6)./profit_trades(:,3));
            avgloss=mean(loss_trades(:,6)./loss_trades(:,3));
        end
        
        function [mdd,day,bars]=getmdd(obj)
            mdd=0;
            peak=-99999;
            for i=1:size(obj.his_equity,1)
                e=obj.his_equity(i);
                if e>peak
                    peak=e;
                end
                dd=100*(peak-e)/peak;
                if dd>mdd
                    mdd=dd;
                    idx=find(obj.his_equity(i:end)>=peak);
                    try
                        d1=datevec(obj.hisdata(idx(1)+i,1));
                        d2=datevec(obj.hisdata(i,1));
                        day=etime(d1,d2);
                        bars=idx(1)-1;
                    catch
                        day=0;
                        bars=0;
                    end
                end
            end
        end
        
        function [ec_figure,obj]=equitycurve(obj,string,error,interval)
            ec_figure=figure('OuterPosition',[100,100,700,700*1.4142]);
            [s_t,s_d]=obj.calSharpeRatio;

            subplot(3,1,3);
            ec=zeros(size(obj.trades,1),1);
            ec(1)=obj.initial_capital+obj.trades(1,6);
            for i=2:size(obj.trades,1)
                ec(i)=ec(i-1)+obj.trades(i,6);
            end
            hold on;
            plot(ec);
            for i=1:size(ec)
                e=ec(i);
                if e==max(ec(1:i))
                    plot(i,e,'Marker','o','MarkerFaceColor','g','MarkerEdgeColor','g','MarkerSize',3);
                end
            end
            title('Equity Curve By Trades','FontWeight','bold')
            hold off;
            
            str=cell(17,1);
            idx=1;
            
            X=['HISTORY DATA(' num2str(size(obj.hisdata,1)) '): missing price(' num2str(error(1)) '), missing volume(' num2str(error(2)) '), consistancy(' num2str(error(3)) '), gap(' num2str(error(4)) '), daily(' num2str(error(4)) ')' ];
            str(idx)={X};
            idx=idx+1;
    
            X=' ';
            str(idx)={X};
            idx=idx+1;
            
            [gp,gl]=obj.getgrosspl();
            X=['Total Net Profit    ',num2str(obj.his_equity(end)-obj.initial_capital) '(' num2str((obj.his_equity(end)-obj.initial_capital)/obj.initial_capital*100) '%)'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            roai=sum(obj.trades(:,6))/sum(obj.trades(:,3))*100;
            %X=['ROAI    ',num2str(roai), '%'];
            %str(idx)={X};
            %idx=idx+1;
            
            X=['Profit Factor   ', num2str(-gp/gl)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
                       
            X=['Gross Profit    ', num2str(gp) '(' num2str(gp/obj.initial_capital) '%)'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
          
            X=['Gross Loss    ', num2str(gl), '(' num2str(gl/obj.initial_capital) '%)'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            [wt,lt,wc,lc,avgw,avgl]=obj.gettradesinfo();
            X=['Total Number of Trades    ', num2str(wt+lt)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Percent Profitable    ', num2str(wt/(wt+lt)*100),'%'];
            obj.pp=wt/(wt+lt)*100;
            str(idx)={X};
            idx=idx+1;
            
            %disp(X);
   
            X=['Avg. Trade Net Profit    ', num2str(sum(obj.trades(:,6))/(wt+lt)) '(' num2str(sum(obj.trades(:,6))/(wt+lt)/obj.initial_capital*100) '%)'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Winning Trades    ', num2str(wt)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Avg. Winning Trade    ', num2str(avgw) '(' num2str(avgw*100), '%)'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Losing Trades    ', num2str(lt)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Avg. Losing Trade    ', num2str(avgl) '(' num2str(avgl*100), '%)'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Ratio: Avg. Winning Trade/Avg. Losing Trade   ', num2str(avgw/avgl)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Max. Consecutive Winning Trades    ', num2str(wc)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Max. Consecutive Losing Trades    ', num2str(lc)];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Largest Winning Trade    ', num2str(max(obj.trades(:,6)./obj.trades(:,3))*100) '%'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Largest Losing Trade    ', num2str(min(obj.trades(:,6)./obj.trades(:,3))*100) '%'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            [mdd,offday,bars]=obj.getmdd();
            X=['Maximum Drawdown    ', num2str(mdd), '%'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            X=['Time off peak    ', convertmin(offday/60), '(' num2str(bars) 'bars)'];
            str(idx)={X};
            idx=idx+1;
            
            %X=['Sharpe Ratio by Trades    ', num2str(s_t)];
            %str(idx)={X};
            %idx=idx+1;
            %disp(X);
            
            X=['Modigliani–Modigliani measure by Days    ', num2str(s_d*100) '%'];
            str(idx)={X};
            idx=idx+1;
            %disp(X);
            
            t1=datevec(obj.trades(:,2));
            t2=datevec(obj.trades(:,1));
            if interval~=-1
                ahp=round(mean(etime(t1,t2))/interval/60);
            else
                ahp=round(mean(etime(t1,t2))/(60*24)/60);
            end
            X=['Avg Holding Period    ', convertmin(mean(etime(t1,t2))/60) '(' num2str(ahp), ' bars)'];
            str(idx)={X};
            idx=idx+1;
            
            trange=floor(obj.hisdata(end,1))-floor(obj.hisdata(1,1))+1;
            atd=size(obj.trades,1)/trange;
            X=['Avg trades per day    ', num2str(atd)];
            str(idx)={X};
            
            subplot(3,1,1);
            axis off;
            text(0,-0.2,str);
            title(obj.middleware.strat.name,'FontWeight','bold')
            text(0,0.8,string);
        end
        
        function obj=finalclearing(obj)
           if size(obj.position,1)>0
                obj.cur_num = obj.cur_num-1;
                p=sum(obj.position(:,2));
                if p>0
                    obj=obj.sell(obj.hisdata(end,5),p,obj.hisdata(end,1));
                else
                    if p<0
                        obj=obj.buy(obj.hisdata(end,5),-p,obj.hisdata(end,1));
                    end
                end
                       
                obj=obj.pairtrade();
                obj.cur_num = obj.cur_num+1;
           end
           %obj.cur_num = obj.cur_num+1;
        end
        
        function obj=reporting_pdf(obj,sname,error,interval,ifsave)
            
            starttime=datestr(min(obj.hisdata(:,1)));
            endtime=datestr(max(obj.hisdata(:,1)));
            string=[sname '  FROM:' starttime '  TO:' endtime];
            if size(obj.position,1)>0
                obj.cur_num=obj.cur_num-1;
            end
            if size(obj.position,1)>0

                p=sum(obj.position(:,2));
                if p>0
                    obj=obj.sell(obj.hisdata(end,5),p,obj.hisdata(end-1,1));
                else
                    if p<0
                        obj=obj.buy(obj.hisdata(end,5),-p,obj.hisdata(end-1,1));
                    end
                end
                       
                obj=obj.pairtrade();
                
            end
                        
            [f,obj]=obj.equitycurve(string,error,interval);
            if ifsave
                try
                    shading interp
                    set(f,'PaperPositionMode','auto')
                    filespec_user=['C:\Users\Vendrefish\Dropbox\code' '\reports\' obj.middleware.strat.sname '_' sname '.pdf'];
                    print(f,'-dpdf',filespec_user);
                catch
                    disp('Saving report file failed!');
                end
            end            
        end
                
        function drawfigure(obj)
            figure;
            hold on;

            names={'open','high','low','close','volume'};
            ps=fints(obj.hisdata(:,1),obj.hisdata(:,2:6),names);
            candle(ps);
            
            for i=1:size(obj.transactions,1)
                t=obj.transactions(i,:);
                if t(2)==1
                    plot(t(1),t(3),'Marker','o','MarkerFaceColor','g','MarkerEdgeColor','g','MarkerSize',10);
                else
                    plot(t(1),t(3),'Marker','o','MarkerFaceColor','r','MarkerEdgeColor','r','MarkerSize',10);
                end
            end
            
            hold off;
        end
        
        function [trades,daily]=calSharpeRatio(obj)
            trades=0;
            if size(obj.trades,1)>0
                trades_return=obj.trades(:,6)./(obj.trades(:,3).*obj.trades(:,5));
                trades=mean(trades_return)/std(trades_return);
            end
            
            daily_return=[];
            daily_rf=[];
            if size(obj.hisdata,1)>0
                startpoint=floor(obj.hisdata(1,1));
                daily_return(end+1)=obj.his_equity(1);
                daily_rf(end+1)=obj.hisdata(1,5);
                for i=1:size(obj.hisdata,1)
                    p=floor(obj.hisdata(i,1));
                    if p-startpoint>=1
                        startpoint=p;
                        daily_return(end+1)=obj.his_equity(i);
                        daily_rf(end+1)=obj.hisdata(i,5);
                    end
                end
            end
            
            daily=0;
            l=size(daily_return,2);
            
            if l>2
                r=daily_return(2:end)-daily_return(1:end-1);
                rf=daily_rf(2:end)-daily_rf(1:end-1);
                r=r./daily_return(2:end);
                rf=rf./daily_rf(2:end);
                daily=(mean(r)-mean(rf))/std(r-rf);
                daily=(daily*std(rf)+mean(rf));
            end
        end
        
        function writeToDatabase(obj,symbol,strat,interval,sname)
            conn = database('hisdata', 'root', '');
            
            filespec_user=['C:\\Users\\Vendrefish\\Dropbox\\code' '\\reports\\' obj.middleware.strat.sname '_' sname '.pdf'];
            
            insertquery='insert into backtest (symbol, strat, starttime, endtime, intervl, net_profit, gross_profit, gross_loss, num_trades, avg_trade_profit, avg_trade_loss, pc_profit, max_cons_win, max_cons_loss, largest_win, largest_loss, drawdown, sharperatio_trades, sharperatio_days, file) values (';
            insertquery=[insertquery '''' symbol ''', ''' strat ''', '];
            starttime=min(obj.hisdata(:,1));
            endtime=max(obj.hisdata(:,1));
            insertquery=[insertquery num2str(starttime) ', ' num2str(endtime) ', ' num2str(interval) ', ' num2str(obj.his_equity(end)-obj.initial_capital) ', '];
            [gp,gl]=obj.getgrosspl();
            insertquery=[insertquery num2str(gp) ', ' num2str(gl) ', '];
            [wt,lt,wc,lc,avgw,avgl]=obj.gettradesinfo();
            mdd=obj.getmdd();
            insertquery=[insertquery num2str(wt+lt) ', ' num2str(avgw) ', ' num2str(avgl) ', ' num2str(wt/(wt+lt)*100) ', ' num2str(wc) ', ' num2str(lc) ', ' num2str(max(obj.trades(:,6))) ', ' num2str(min(obj.trades(:,6))) ', ' num2str(mdd)];
            [s_t,s_d]=obj.calSharpeRatio;
            insertquery=[insertquery ', ' num2str(s_t) ', ' num2str(s_d) ' ,''' filespec_user ''')'];
            exec(conn,insertquery);
            close(conn);
        end
    end
    
end

function [p,obj]=pairtrades(obj,p)
    
    if size(p,1)>1
        op=p(1,2);        
        idx=find(p(:,2)*op<0);
        while size(p,1)>0 && abs(sum(p(idx,2)))>=abs(op)
            %keyboard
            dlist=[];
            for i=idx'
                if abs(op)>abs(p(i,2))
                    op=op+p(i,2);
                    dlist(end+1,:)=i;
                else
                    p(i,2)=p(i,2)+op;
                    price=abs((p(dlist,2)'*p(dlist,3)-op*p(i,3))/(sum(p(dlist,2))-op));
                    obj.trades(end+1,:)=[p(1,1),p(i,1),p(1,3),price,p(1,2),(price-p(1,3))*p(1,2)];
                    if p(i,2)==0
                        dlist(end+1,:)=i;
                    end
                    break
                end
            end
            p(dlist,:)=[];
            p(1,:)=[];
            if size(p,1)>0
                op=p(1,2);        
                idx=find(p(:,2)*op<0);
            end
        end
        %keyboard
    end
    
end

function str=convertmin(m)
str='';
d=floor(m/60/24);
if d>0
    m=m-d*60*24;
    str=[str num2str(d) 'days '];
end

h=floor(m/60);
if h>0
    m=m-h*60;
    str=[str num2str(h) 'hours '];
end
m=round(m);
str=[str num2str(m) 'minites '];
end
