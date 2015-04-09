function [ price ] = slipage( price, type )
%Calulation of spread/slipage
%   Detailed explanation goes here
    s_long=0.0;
    s_short=0.0;
    
    if type==1
        price=price*(1+s_long);
    else
        price=price*(1-s_short);
    end
   
end