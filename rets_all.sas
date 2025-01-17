libname home '.';

PROC SQL;        
  CREATE TABLE crsp_dates AS
  SELECT date, intnx('MONTH', date, 0, 'BEGINNING') AS month format=yymmdd10.
  FROM crsp.msi
  ORDER BY date;
QUIT;

DATA crsp_dates;
  SET crsp_dates;
  td = _n_;
RUN;

PROC SQL;
  CREATE VIEW annc_events AS
  SELECT  gvkey, datadate, rdq,
	intnx('MONTH', rdq, 0, 'BEGINNING') AS annc_month format=yymmdd10.
  FROM comp.fundq
  WHERE indfmt = 'INDL' AND datafmt = 'STD'
    AND consol = 'C' AND popsrc = 'D' 
    AND fqtr = 4 AND fyr = 12 AND rdq IS NOT NULL;

  CREATE VIEW annc_months AS
  SELECT month AS annc_month, td AS annc_td,
  	annc_td - 11 AS start_td, annc_td + 6 AS end_td
  FROM crsp_dates;

  CREATE VIEW td_link AS 
  SELECT annc_month, td - annc_td AS rel_td, date
  FROM crsp_dates 
  INNER JOIN annc_months
  ON td BETWEEN start_td AND end_td;

  CREATE VIEW ccm_link AS
  SELECT gvkey, lpermno AS permno, linkdt, 
  	coalesce(linkenddt, max(linkenddt)) AS linkenddt
  FROM crsp.ccmxpf_lnkhist
  WHERE linktype IN ("LC", "LU", "LS")
    AND linkprim IN ("C", "P");

  CREATE TABLE home.rets_all AS 
  SELECT a.gvkey, a.datadate, b.rel_td, c.permno, b.date, d.ret
  FROM annc_events AS a
  INNER JOIN td_link AS b
  ON a.annc_month = b.annc_month
  INNER JOIN ccm_link AS c
  ON a.gvkey = c.gvkey
  INNER JOIN crsp.msf AS d
  ON c.permno = d.permno AND b.date = d.date
  INNER JOIN crsp.stocknames AS e
  ON d.permno = e.permno 
    AND d.date BETWEEN e.namedt AND e.nameenddt
  WHERE a.annc_month >= c.linkdt 
  	AND a.annc_month <= c.linkenddt
  	AND exchcd IN (1, 2, 3)
  	AND a.datadate BETWEEN '01Jan1987'd AND '31Dec2002'd;
QUIT;