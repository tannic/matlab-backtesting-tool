classdef backtest_middleware
    
    properties
        orderbook
                  
        ordertype
        
        strat
        
        hisorders
        
        
    end
    
    methods
        function obj=backtest_middleware(strat)
            obj.orderbook=[];
            
            obj.ordertype={'MKT','LMT','STP','TRAIL','CLS','OCLS'};
            
            obj.strat=strat;
            
            obj.hisorders=[];
        end
        
        function [signals,obj]=feed(obj,datafeed,position,capital,hisdata)
            
            signals=[];
            
            if size(obj.orderbook,1)~=0
                
                i=1;
                if size(obj.orderbook,2)==0
                    obj.orderbook=[];
                end
                while i<=size(obj.orderbook,1)
                    
                    [signal,ifdelete,order]=processorder(obj.orderbook(i,:),datafeed,hisdata(end,1),hisdata(end,:)); 
                    if ifdelete==1
                        
                        obj.hisorders=[obj.hisorders;obj.orderbook(i,:)];
                        obj.orderbook(i,:)=[];
                        i=i-1;
                    else
                        obj.orderbook(i,:)=order;
                    end
                    if size(signal,1)~=0
                        signals(end+1,:)=signal;
                    end
                    
                    
                    i=i+1;
                end
            
            end
            

            
        end
        
        function [obj]=feed2(obj,datafeed,position,capital,hisdata)
            
            idx={};
            for j=1:size(obj.orderbook,1)
                idx{end+1}=obj.orderbook(j).id;
            end
            
            [orders,cids,obj.strat]=obj.strat.feed(datafeed,position,capital,idx,hisdata);
            
            for i=1:size(orders,1)
                exist=0;
                for j=1:size(obj.orderbook,1)
                    if size(obj.orderbook,2)~=0 && strcmp(orders(i).id,obj.orderbook(j).id)
                        obj.orderbook(j)=orders(i);
                        exist=1;
                    end
                end
                if exist==0
                    obj.orderbook=[obj.orderbook;orders(i)];
                end
            end
            
            if size(obj.orderbook,1)~=0
                
                i=1;
                while i<=size(obj.orderbook,1)
                   
                    if size(obj.orderbook,2)~=0 && sum(strfind(cids,obj.orderbook(i).id))~=0
                        obj.orderbook(i)=[];
                        i=i-1;
                    end
                    
                    i=i+1;
                end
            
            end
        end
        
    end
    
    
    
end
% signal=[buy/sell, lot, price]
function [signal,ifdelete,order]=processorder(order,datafeed,previousdate,hisdata)
    switch(order.orderType)
        
        case 'OPEN'
            signal=[order.action, order.totalQuantity, hisdata(:,2)];
            ifdelete=1;
        case 'OCLS'
            signal=[order.action, order.totalQuantity, hisdata(:,5)];
            ifdelete=1;
        case 'CLS'
            signal=[order.action, order.totalQuantity, datafeed(:,5)];
            ifdelete=1;
        case 'MKT'
            signal=[order.action, order.totalQuantity, datafeed(:,2)];
            ifdelete=1;
        case 'LMT'
            if order.lmtPrice<datafeed(:,3) && order.lmtPrice>datafeed(:,4)
                signal=[order.action, order.totalQuantity, order.lmtPrice];
                ifdelete=1;
            else
                signal=[];
                ifdelete=1;
            end
        case 'STP'
            if order.action==1
                if  order.auxPrice>datafeed(:,4)
                    signal=[-order.action, order.totalQuantity, order.auxPrice];
                    ifdelete=1;
                else
                    if order.lmtPrice~=0 && order.lmtPrice<datafeed(:,3) && order.lmtPrice>datafeed(:,4)
                        signal=[-order.action, order.totalQuantity, order.lmtPrice];
                        ifdelete=1;
                    else
                        if order.lmtPrice~=0 && order.lmtPrice<datafeed(:,3) && order.lmtPrice<datafeed(:,4)
                            signal=[-order.action, order.totalQuantity, datafeed(:,2)];
                            ifdelete=1;
                        else
                            signal=[];
                            ifdelete=0;
                        end
                    end
                end
            else
                if  order.auxPrice < datafeed(:,3)
                    signal=[-order.action, order.totalQuantity, order.auxPrice];
                    ifdelete=1;
                else
                    if order.lmtPrice~=0 && order.lmtPrice<datafeed(:,3) && order.lmtPrice>datafeed(:,4)
                        signal=[-order.action, order.totalQuantity, order.lmtPrice];
                        ifdelete=1;
                    else
                        if order.lmtPrice~=0 && order.lmtPrice>datafeed(:,3) && order.lmtPrice>datafeed(:,4)
                            signal=[-order.action, order.totalQuantity, datafeed(:,2)];
                            ifdelete=1;
                        else
                            signal=[];
                            ifdelete=0;
                        end
                    end
                end
            end
        case 'TRAIL'
            
            if order.action==1
                if order.timestamp==previousdate
                    order.trailStopPrice=datafeed(:,2)*(1-order.trailingPercent);
                end
                if order.trailStopPrice>datafeed(:,4)
                    price=min(order.trailStopPrice,datafeed(:,3));
                    signal=[-order.action, order.totalQuantity, price];
                    ifdelete=1;
                else
                    signal=[];
                    ifdelete=0;
                    if datafeed(:,5)>order.trailStopPrice/(1-order.trailingPercent);
                        order.trailStopPrice=datafeed(:,5)*(1-order.trailingPercent);
                    end
                end
            else
                if order.timestamp==previousdate
                    order.trailStopPrice=datafeed(:,2)*(1+order.trailingPercent);
                end
                if order.trailStopPrice<datafeed(:,3)
                    price=max(order.trailStopPrice,datafeed(:,4));
                    signal=[-order.action, order.totalQuantity, price];
                    ifdelete=1;
                else
                    signal=[];
                    ifdelete=0;
                    if datafeed(:,5)<order.trailStopPrice/(1+order.trailingPercent);
                        order.trailStopPrice=datafeed(:,5)*(1+order.trailingPercent);
                    end
                end
            end
        otherwise
            ifdelete=1;
            signal=[];
    end
    %if size(signal,1)~=0 && signal(2)<0
    %    signal
    %    order
    %end
    %ifdelete
    %order
end