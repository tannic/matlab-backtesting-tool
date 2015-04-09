function data=loaddata2(sname,interval,starttime,endtime)
    
    oriname=sname;

    sname=strrep(sname, ' ', '_');
    sname=strrep(sname, '/', '');
    sname=strrep(sname, '-', '');
    
    ai=[1,5,15,60,-1];
    if sum(ai==interval)~=0
        if interval==-1
            sname=strrep(sname, '*', '');
            sname=[sname '_' 'daily'];
        else
            sname=[sname '_' num2str(interval) 'min'];
        end
    else
        sname=[sname '_' num2str(1) 'min'];
    end
    sname=strrep(sname, '/', '');
        
    starttime=datenum(starttime);
    endtime=datenum(endtime);
    %Set preferences with setdbprefs.
    setdbprefs('DataReturnFormat', 'numeric');
    setdbprefs('NullNumberRead', 'NaN');
    setdbprefs('NullStringRead', 'null');

    try
        %Make connection to database.  Note that the password has been omitted.
        %Using ODBC driver.
        conn = database('hisdata', 'root', '');

        table=sname;

        curs = exec(conn, ['SELECT * FROM historicaldata.' table ' '...
            ' WHERE ' table '.time BETWEEN ' num2str(starttime) ' AND ' num2str(endtime) ...
            ' ORDER BY 	' table '.time DESC ']);

        curs = fetch(curs);
        close(curs);

        %Assign data to output variable
        P = curs.Data;

        %Close database connection.
        close(conn);

        %Clear variables
        clear curs conn

        if sum(ai==interval)==0
            P=constructcandle(P,interval);
        end
        
        if size(P,2)<2
            c=yahoo;
            if interval==-1
                P=fetch(c,oriname,starttime,endtime);
            else
                disp('error fetching data!');
            end
        end
        
    catch
        c=yahoo;
        if interval==-1
            P=fetch(c,oriname,starttime,endtime);
        else
            disp('error fetching data!');
        end
    end
    data=P; 
end

function nfts=constructcandle(fts,interval)

mind=floor(min(fts(:,1)));
maxd=ceil(max(fts(:,1)));

m=ceil(240*60/interval);
length=maxd-mind;
nfts=zeros(length*m,6);

curd=datevec(maxd);

i=1;

while datenum(curd)>mind
    upperbound=datenum(curd);
    lowerbound=max(datenum(curd-[0 0 0 0 interval 0]),mind);
    
    idx=fts(:,1)<upperbound.*(fts(:,1)>=lowerbound);
    sfts=fts(idx,:);
    if size(sfts,1)>0
        nfts(i,1)=upperbound;
        nfts(i,2)=sfts(end,2);
        nfts(i,3)=max(sfts(:,3));
        nfts(i,4)=min(sfts(:,4));
        nfts(i,5)=sfts(1,5);
        nfts(i,6)=sum(sfts(:,6));
    end
    
    curd=datevec(lowerbound);
    i=i+1;
end

nfts(nfts(:,1)==0,:)=[];

end