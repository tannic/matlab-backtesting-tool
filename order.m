classdef order
    properties
        id
        % 1. BUY -1. SELL
        action
        % This is the STOP price for stop-limit orders, and the offset amount for relative orders. In all other cases, specify zero.
        auxPrice
        % This is the LIMIT price, used for limit, stop-limit and relative orders. In all other cases specify zero. For relative orders with no limit price, also specify zero.
        lmtPrice
        % orderType
        orderType
        % order quantity
        totalQuantity
        
        trailStopPrice
        trailingPercent
        
        timestamp
    end
    methods
        function obj=order(action, aux, lmt, type, tq, ts, tp,time)

            obj.id=generate_guid;
            
            obj.action=action;
            obj.auxPrice=aux;
            obj.lmtPrice=lmt;
            obj.orderType=type;
            obj.totalQuantity=tq;
            obj.trailStopPrice=ts;
            obj.trailingPercent=tp;
            obj.timestamp=time;
            
        end
        
    end
end