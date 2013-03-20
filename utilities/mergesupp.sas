/*******************************************************************************
Copyright (c) 2013 Tomas Demcenko

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
********************************************************************************
@Author(s):
    Tomas Demcenko

@Contributors:

@Description: To merge SDTM supplemental qualifiers back to the domain dataset.

@Dependencies:

@Inputs: &DSIN &SUPPDSIN

@Outputs: &DSOUT

@Required parameters:
    DSIN=: input dataset, ex. libname.memname.

@Optional parameters:
    SUPPDS=: if blank, library where &DSIN resides will be checked for SUPPQUAL and
        SUPPxx. If both exist - both will be used to merge back the data. Multiple
        supplemental dataset can be specified here. If value is SUPP* then all
        supplemental datasets from the same lib as &DSIN will be used.
    DSOUT=: output dataset, default: work.<&DSIN memname>_v

@Notes: Macro should be called outside data step. Output dataset will be overwritten.
    Temporary datasets __TMP01 __TMP02 will be created and deleted after running.

@BLOB: $Id$
*******************************************************************************/
%macro mergesupp(dsin=, suppds=, dsout=);
    %put Macro &sysmacroname started.;
    %local __startdt;
    %let __startdt = %sysfunc(datetime());

    %if %sysfunc(%superq(DSIN)=,boolean) %then %do;
        %put DSIN is a required parameter.;
        %goto macro_end;
    %end;

    %if not %sysfunc(exist(&dsin)) %then %do;
        %put Dataset &DSIN does not exist.;
        %goto macro_end;
    %end;

    %if not %index(&DSIN, %str(.)) %then %let DSIN = WORK.%upcase(&DSIN);
    %else %let dsin = %upcase(&dsin);

    %local libname memname supps i sup idvars idvar id;
    %let libname = %scan(&DSIN, 1, %str(.));
    %let memname = %scan(&DSIN, 2, %str(.));

    %* output *;
    %if &dsout eq %str() %then %let dsout = WORK.&memname._v;

    %* check if SUPP dataset(s) exist *;
    %let suppds = %upcase(&suppds);
    proc sql noprint;
        select distinct cats(catx(".", libname, memname), '(where=(rdomain="',"&memname", '"))') into :supps separated by " "
            from sashelp.vstable where
                %if %str(&SUPPDS) eq %str(SUPP*) %then %do;
                    libname eq "&libname" and index(memname, "SUPP") eq 1
                %end;
                %else %if %str(&SUPPDS) eq %str() %then %do;
                    libname eq "&libname" and memname in ("SUPPQUAL" "SUPP&MEMNAME")
                %end;
                %else %do;
                    catx('.', libname, memname) in
                        (
                            %let i = 1;
                            %do %while(%scan(%str(&SUPPDS), &i, %str( )));
                                %let sup = %scan(%str(&SUPPDS), &i, %str( ));
                                %if not %sysfunc(exist(&sup)) %then %do;
                                    %put WA%str()RNING: supplemental dataset &SUP does not exist.;
                                %end;
                                %else %do;
                                    "&SUP"
                                %end;
                                %let i = %eval(&i + 1);
                            %end;
                        )
                %end;
        ;
    quit;

    data &dsout;
        set &dsin;
    run;

    %if %str(&supps) eq %str() %then %do;
        %put NOTE: no supplemental datasets found.;
        %goto macro_end;
    %end;

    %* so there exists supplemental dataset - need to merge by ID variable. *;
    %* temporary supplemental dataset from all sources where RDOMAIN is the same as &DSIN memname*;
    data __TMP01;
        set &supps;
    run;

    proc sort data=_TMP01;
        by studyid usubjid rdomain idvar idvarval;
    run;

    proc sql noprint;
        select distinct cats('"', idvar, '"') into :IDVARS separated by " "
            from __TMP01;
    quit;

    %let i = 1;
    %do %while(%scan(%str(&idvars), &i, %str( ))) %then %do;
        %let idvar = %scan(%str(&idvars), &i, %str( ));

        %if %str(&idvar) eq %str("") %then %let id = ;
        %else %let id = idvar idvarval;
        proc transpose data=__TMP01(where=(idvar eq &idvar)) out=__TMP02;
            by studyid usubjid rdomain &id;
            id qnam;
            idlabel qlabel;
            var qval;
        run;

        %*check if variable is numeric - if yes, input IDVARVAL as best.;
        

        data &dsout;
            if _N_ eq 1 then do;
                if 0 

        %let i = %eval(&i + 1);
    %end;

    %macro_end:
    %put Macro &sysmacroname finished in %sysfunc(putn(%sysevalf(%sysfunc(datetime()) - &__startdt), tod.));
%mend mergesupp;

/* Usage:

%mergesupp(dsin=sdtm.dm, suppds=sdtm.suppdm, dsout=work.dm_v);

/**/
