function [ com ] = brokage( lot, type )
%Calulation of brokage fee depending on price,lot, type (long/short)
    
PRICE_LONG=0.02;
PRICE_SHORT=0.02;

if type==1
    com=PRICE_LONG*lot;
else
    com=PRICE_SHORT*lot;
end

end

