/* Задача скрипта - рассчитать площади и процентное соотношение
покрытий заданной территории разными спутниками.
Скрипт работает из расчёта, что у нас есть две таблицы: aoi и coverage_all.
Обе таблицы должны быть в прямоугольной СК, например 3857. */

/* Подготовка таблиц к работе (проверка корректности геометрии).
Это не работает с данными в географических СК */

UPDATE dm2014.aoi_complex
   SET geom = ST_MakeValid(geom)
 WHERE NOT ST_IsValid(geom);

UPDATE dm2014.coverage_all
   SET geom = ST_MakeValid(geom)
 WHERE NOT ST_IsValid(geom);
-- Время выполнения: 1 сек

/* Упрощаем геометрию области интереса */
CREATE TABLE dm2014.aoi AS
     (SELECT gid, ST_SimplifyPreserveTopology(dm2014.aoi_complex.geom, 200) AS geom
        FROM dm2014.aoi_complex
     );
-- Время выполнения: 2,5 сек

/* На этом этапе мы фильтруем coverage_all в соответствии с требованиями
Сначала узнаем, какие спутники есть в подборке */
SELECT DISTINCT satname
  FROM dm2014.coverage_all;

/* Создаём объединённую таблицу AOI для ускорения последующей обработки*/
CREATE TABLE dm2014.merge_aoi AS
     (SELECT ST_Union(dm2014.aoi.geom) AS geom
        FROM dm2014.aoi);
-- Время выполнения: 1 сек

-- выборка снимков по критериям
CREATE TABLE dm2014.coverage1 AS
     (SELECT *
        FROM dm2014.coverage_all
       WHERE acqdate BETWEEN '2014-05-10' AND '2014-10-20' AND
             ((cloudcover < 11) OR (cloudcover IS NULL)) AND
             ((ABS(offnadir) < 31) OR (offnadir IS NULL))
             );

-- Нахождение полезного покрытия (обрезка всех отобранных снимков по AOI)
CREATE TABLE dm2014.coverage_useful AS
     (SELECT gid, satname, catalogid, acqdate, cloudcover,
     offnadir, sunelev, sunazim,  browseurl, filename,
     ST_Intersection(dm2014.merge_aoi.geom, dm2014.coverage1.geom) AS geom
        FROM dm2014.merge_aoi, dm2014.coverage1);


/* Создаём объединённые таблицы по спутникам  */
/* DigitalGLobe */
CREATE TABLE dm2014.merge_dg AS
     (SELECT ST_Union(dm2014.coverage_useful.geom) AS geom
        FROM dm2014.coverage_useful
       WHERE satname IN ('WV01', 'QB02', 'GE01', 'WV02', 'WV03'));

/* AirBus */
CREATE TABLE dm2014.merge_airbus AS
     (SELECT ST_Union(dm2014.coverage_useful.geom) AS geom
        FROM dm2014.coverage_useful
       WHERE satname IN ('SPOT 5(A)', 'SPOT 6/7(A)', 'Pleiades'));

/* Scanex */
CREATE TABLE dm2014.merge_scanex AS
     (SELECT ST_Union(dm2014.coverage_useful.geom) AS geom
        FROM dm2014.coverage_useful
       WHERE satname IN ('SPOT 5', 'SPOT 6/7'));

/* BlackBridge */
CREATE TABLE dm2014.merge_re AS
     (SELECT ST_Union(dm2014.coverage_useful.geom) AS geom
        FROM dm2014.coverage_useful
       WHERE satname IN ('RapidEye'));

/* Belarus */
CREATE TABLE dm2014.merge_belarus AS
     (SELECT ST_Union(dm2014.coverage_useful.geom) AS geom
        FROM dm2014.coverage_useful
       WHERE satname IN ('BKA', 'Canopus-V'));

/* China */
CREATE TABLE dm2014.merge_china AS
     (SELECT ST_Union(dm2014.coverage_useful.geom) AS geom
        FROM dm2014.coverage_useful
       WHERE satname IN ('TH-1', 'GF1', 'ZY3'));
-- Время выполнения: 31сек

/* Обновляем топологию полигонов перед дальнейшей обработкой */
UPDATE dm2014.merge_china
   SET geom = ST_MakeValid(geom)
 WHERE NOT ST_IsValid(geom);

 UPDATE dm2014.merge_re
   SET geom = ST_MakeValid(geom)
 WHERE NOT ST_IsValid(geom);

/*
Ошибка типа "ОШИБКА: GEOSUnion: TopologyException: found non-noded intersection between LINESTRING (1.51127e+007 5.59064e+006, 1.51126e+007 5.6011e+006) and LINESTRING (1.50958e+007 5.60501e+006, 1.5113e+007 5.60102e+006) at 15112630.128012424 5601096.2883474464
SQL state: XX000"
решается путем создания мини-буфера вокруг проблемных полигонов.
В данном случае - это merge_re и merge_china

 */

/* Покрытие тендера по двойным комбинациям спутников */
CREATE TABLE dm2014.dg_airbus AS
     (SELECT ST_Union(dm2014.merge_dg.geom, dm2014.merge_airbus.geom) AS geom
        FROM dm2014.merge_dg, dm2014.merge_airbus);
-- Время выполнения: 1.3 сек

CREATE TABLE dm2014.dg_scanex AS
     (SELECT ST_Union(dm2014.merge_dg.geom, dm2014.merge_scanex.geom) AS geom
        FROM dm2014.merge_dg, dm2014.merge_scanex);
-- Время выполнения: 15мин

CREATE TABLE dm2014.dg_re AS
     (SELECT ST_Union(dm2014.merge_dg.geom, dm2014.merge_re.geom) AS geom
        FROM dm2014.merge_dg, dm2014.merge_re);
-- Время выполнения: 41мин

CREATE TABLE dm2014.dg_belarus AS
     (SELECT ST_Union(dm2014.merge_dg.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.merge_dg, dm2014.merge_belarus);

CREATE TABLE dm2014.dg_china AS
     (SELECT ST_Union(dm2014.merge_dg.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.merge_dg, dm2014.merge_china);

CREATE TABLE dm2014.airbus_scanex AS
     (SELECT ST_Union(dm2014.merge_airbus.geom, dm2014.merge_scanex.geom) AS geom
        FROM dm2014.merge_airbus, dm2014.merge_scanex);

CREATE TABLE dm2014.airbus_re AS
     (SELECT ST_Union(dm2014.merge_airbus.geom, dm2014.merge_re.geom) AS geom
        FROM dm2014.merge_airbus, dm2014.merge_re);

CREATE TABLE dm2014.airbus_belarus AS
     (SELECT ST_Union(dm2014.merge_airbus.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.merge_airbus, dm2014.merge_belarus);

CREATE TABLE dm2014.airbus_china AS
     (SELECT ST_Union(dm2014.merge_airbus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.merge_airbus, dm2014.merge_china);

CREATE TABLE dm2014.scanex_re AS
     (SELECT ST_Union(dm2014.merge_scanex.geom, dm2014.merge_re.geom) AS geom
        FROM dm2014.merge_scanex, dm2014.merge_re);

CREATE TABLE dm2014.scanex_belarus AS
     (SELECT ST_Union(dm2014.merge_scanex.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.merge_scanex, dm2014.merge_belarus);

CREATE TABLE dm2014.scanex_china AS
     (SELECT ST_Union(dm2014.merge_scanex.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.merge_scanex, dm2014.merge_china);

CREATE TABLE dm2014.re_belarus AS
     (SELECT ST_Union(dm2014.merge_re.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.merge_re, dm2014.merge_belarus);

CREATE TABLE dm2014.re_china AS
     (SELECT ST_Union(dm2014.merge_re.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.merge_re, dm2014.merge_china);

CREATE TABLE dm2014.belarus_china AS
     (SELECT ST_Union(dm2014.merge_belarus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.merge_belarus, dm2014.merge_china);

/* Покрытие тендера по тройным комбинациям спутников */

CREATE TABLE dm2014.dg_airbus_scanex AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.merge_scanex.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.merge_scanex);

CREATE TABLE dm2014.dg_airbus_re AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.merge_re.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.merge_re);

CREATE TABLE dm2014.dg_airbus_belarus AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.merge_belarus);

CREATE TABLE dm2014.dg_airbus_china AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.merge_china);

CREATE TABLE dm2014.dg_scanex_re AS
     (SELECT ST_Union(dm2014.dg_scanex.geom, dm2014.merge_re.geom) AS geom
        FROM dm2014.dg_scanex, dm2014.merge_re);

CREATE TABLE dm2014.dg_scanex_belarus AS
     (SELECT ST_Union(dm2014.dg_scanex.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.dg_scanex, dm2014.merge_belarus);

CREATE TABLE dm2014.dg_scanex_china AS
     (SELECT ST_Union(dm2014.dg_scanex.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.dg_scanex, dm2014.merge_china);

CREATE TABLE dm2014.dg_re_belarus AS
     (SELECT ST_Union(dm2014.dg_re.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.dg_re, dm2014.merge_belarus);

CREATE TABLE dm2014.dg_re_china AS
     (SELECT ST_Union(dm2014.dg_re.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.dg_re, dm2014.merge_china);

CREATE TABLE dm2014.dg_belarus_china AS
     (SELECT ST_Union(dm2014.dg_belarus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.dg_belarus, dm2014.merge_china);

CREATE TABLE dm2014.airbus_scanex_re AS
     (SELECT ST_Union(dm2014.airbus_scanex.geom, dm2014.merge_re.geom) AS geom
        FROM dm2014.airbus_scanex, dm2014.merge_re);

CREATE TABLE dm2014.airbus_scanex_belarus AS
     (SELECT ST_Union(dm2014.airbus_scanex.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.airbus_scanex, dm2014.merge_belarus);

CREATE TABLE dm2014.airbus_scanex_china AS
     (SELECT ST_Union(dm2014.airbus_scanex.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.airbus_scanex, dm2014.merge_china);

CREATE TABLE dm2014.airbus_re_belarus AS
     (SELECT ST_Union(dm2014.airbus_re.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.airbus_re, dm2014.merge_belarus);

CREATE TABLE dm2014.airbus_re_china AS
     (SELECT ST_Union(dm2014.airbus_re.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.airbus_re, dm2014.merge_china);

CREATE TABLE dm2014.airbus_belarus_china AS
     (SELECT ST_Union(dm2014.airbus_belarus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.airbus_belarus, dm2014.merge_china);

CREATE TABLE dm2014.scanex_re_belarus AS
     (SELECT ST_Union(dm2014.scanex_re.geom, dm2014.merge_belarus.geom) AS geom
        FROM dm2014.scanex_re, dm2014.merge_belarus);

CREATE TABLE dm2014.scanex_re_china AS
     (SELECT ST_Union(dm2014.scanex_re.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.scanex_re, dm2014.merge_china);

CREATE TABLE dm2014.scanex_belarus_china AS
     (SELECT ST_Union(dm2014.scanex_belarus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.scanex_belarus, dm2014.merge_china);

CREATE TABLE dm2014.re_belarus_china AS
     (SELECT ST_Union(dm2014.re_belarus.geom, dm2014.merge_china.geom) AS geom
        FROM dm2014.re_belarus, dm2014.merge_china);

/* Покрытие тендера по четверным комбинациям спутников */

CREATE TABLE dm2014.dg_airbus_scanex_re AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.scanex_re.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.scanex_re);

CREATE TABLE dm2014.dg_airbus_scanex_belarus AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.scanex_belarus.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.scanex_belarus);

CREATE TABLE dm2014.dg_airbus_scanex_china AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.scanex_china.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.scanex_china);

CREATE TABLE dm2014.dg_airbus_re_belarus AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.re_belarus.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.re_belarus);

CREATE TABLE dm2014.dg_airbus_re_china AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.re_china.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.re_china);

CREATE TABLE dm2014.dg_airbus_belarus_china AS
     (SELECT ST_Union(dm2014.dg_airbus.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.dg_airbus, dm2014.belarus_china);

CREATE TABLE dm2014.dg_scanex_re_belarus AS
     (SELECT ST_Union(dm2014.dg_scanex.geom, dm2014.re_belarus.geom) AS geom
        FROM dm2014.dg_scanex, dm2014.re_belarus);

CREATE TABLE dm2014.dg_scanex_re_china AS
     (SELECT ST_Union(dm2014.dg_scanex.geom, dm2014.re_china.geom) AS geom
        FROM dm2014.dg_scanex, dm2014.re_china);

CREATE TABLE dm2014.dg_scanex_belarus_china AS
     (SELECT ST_Union(dm2014.dg_scanex.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.dg_scanex, dm2014.belarus_china);

CREATE TABLE dm2014.dg_re_belarus_china AS
     (SELECT ST_Union(dm2014.dg_re.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.dg_re, dm2014.belarus_china);

CREATE TABLE dm2014.airbus_scanex_re_belarus AS
     (SELECT ST_Union(dm2014.airbus_scanex.geom, dm2014.re_belarus.geom) AS geom
        FROM dm2014.airbus_scanex, dm2014.re_belarus);

CREATE TABLE dm2014.airbus_scanex_re_china AS
     (SELECT ST_Union(dm2014.airbus_scanex.geom, dm2014.re_china.geom) AS geom
        FROM dm2014.airbus_scanex, dm2014.re_china);

CREATE TABLE dm2014.airbus_scanex_belarus_china AS
     (SELECT ST_Union(dm2014.airbus_scanex.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.airbus_scanex, dm2014.belarus_china);

CREATE TABLE dm2014.airbus_re_belarus_china AS
     (SELECT ST_Union(dm2014.airbus_re.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.airbus_re, dm2014.belarus_china);

CREATE TABLE dm2014.scanex_re_belarus_china AS
     (SELECT ST_Union(dm2014.scanex_re.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.scanex_re, dm2014.belarus_china);

/* Покрытие тендера по пятерным комбинациям спутников */

CREATE TABLE dm2014.dg_airbus_scanex_re_belarus AS
     (SELECT ST_Union(dm2014.dg_airbus_scanex.geom, dm2014.re_belarus.geom) AS geom
        FROM dm2014.dg_airbus_scanex, dm2014.re_belarus);

CREATE TABLE dm2014.dg_airbus_scanex_re_china AS
     (SELECT ST_Union(dm2014.dg_airbus_scanex.geom, dm2014.re_china.geom) AS geom
        FROM dm2014.dg_airbus_scanex, dm2014.re_china);

CREATE TABLE dm2014.dg_airbus_scanex_belarus_china AS
     (SELECT ST_Union(dm2014.dg_airbus_scanex.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.dg_airbus_scanex, dm2014.belarus_china);

CREATE TABLE dm2014.dg_airbus_re_belarus_china AS
     (SELECT ST_Union(dm2014.dg_airbus_re.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.dg_airbus_re, dm2014.belarus_china);

CREATE TABLE dm2014.dg_scanex_re_belarus_china AS
     (SELECT ST_Union(dm2014.dg_scanex_re.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.dg_scanex_re, dm2014.belarus_china);

CREATE TABLE dm2014.airbus_scanex_re_belarus_china AS
     (SELECT ST_Union(dm2014.airbus_scanex_re.geom, dm2014.belarus_china.geom) AS geom
        FROM dm2014.airbus_scanex_re, dm2014.belarus_china);

/* Покрытие тендера по всем спутникам */

CREATE TABLE dm2014.dg_airbus_scanex_re_belarus_china AS
     (SELECT ST_Union(dm2014.dg_airbus_scanex.geom, dm2014.re_belarus_china.geom) AS geom
        FROM dm2014.dg_airbus_scanex, dm2014.re_belarus_china);

/* Уникальные покрытия тендера по спутникам рассчитываются для выбранных комбинаций отдельно
по просьбе руководства */

CREATE TABLE dm2014.uniscanex AS
     (SELECT ST_Difference(dm2014.merge_scanex.geom, dm2014.dg_airbus_re_belarus_china.geom) AS geom
        FROM dm2014.merge_scanex, dm2014.dg_airbus_re_belarus_china);
CREATE TABLE dm2014.unidg AS
     (SELECT ST_Difference(dm2014.merge_dg.geom, dm2014.airbus_scanex_re_belarus_china.geom) AS geom
        FROM dm2014.merge_dg, dm2014.airbus_scanex_re_belarus_china);
CREATE TABLE dm2014.unire AS
     (SELECT ST_Difference(dm2014.merge_re.geom, dm2014.dg_airbus_scanex_belarus_china.geom) AS geom
        FROM dm2014.merge_re, dm2014.dg_airbus_scanex_belarus_china);
CREATE TABLE dm2014.uniairbus AS
     (SELECT ST_Difference(dm2014.merge_airbus.geom, dm2014.dg_scanex_re_belarus_china.geom) AS geom
        FROM dm2014.merge_airbus, dm2014.dg_scanex_re_belarus_china);
CREATE TABLE dm2014.unibelarus AS
     (SELECT ST_Difference(dm2014.merge_belarus.geom, dm2014.dg_airbus_scanex_re_china.geom) AS geom
        FROM dm2014.merge_belarus, dm2014.dg_airbus_scanex_re_china);
CREATE TABLE dm2014.unichina AS
     (SELECT ST_Difference(dm2014.merge_china.geom, dm2014.dg_airbus_scanex_re_belarus.geom) AS geom
        FROM dm2014.merge_china, dm2014.dg_airbus_scanex_re_belarus);

/* Именование комбинаций */
ALTER TABLE dm2014.merge_dg ADD COLUMN name varchar;
UPDATE dm2014.merge_dg SET name = 'merge_dg';
ALTER TABLE dm2014.merge_airbus ADD COLUMN name varchar;
UPDATE dm2014.merge_airbus SET name = 'merge_airbus';
ALTER TABLE dm2014.merge_scanex ADD COLUMN name varchar;
UPDATE dm2014.merge_scanex SET name = 'merge_scanex';
ALTER TABLE dm2014.merge_re ADD COLUMN name varchar;
UPDATE dm2014.merge_re SET name = 'merge_re';
ALTER TABLE dm2014.merge_belarus ADD COLUMN name varchar;
UPDATE dm2014.merge_belarus SET name = 'merge_belarus';
ALTER TABLE dm2014.merge_china ADD COLUMN name varchar;
UPDATE dm2014.merge_china SET name = 'merge_china';
ALTER TABLE dm2014.unidg ADD COLUMN name varchar;
UPDATE dm2014.unidg SET name = 'unidg';
ALTER TABLE dm2014.uniairbus ADD COLUMN name varchar;
UPDATE dm2014.uniairbus SET name = 'uniairbus';
ALTER TABLE dm2014.uniscanex ADD COLUMN name varchar;
UPDATE dm2014.uniscanex SET name = 'uniscanex';
ALTER TABLE dm2014.unire ADD COLUMN name varchar;
UPDATE dm2014.unire SET name = 'unire';
ALTER TABLE dm2014.unibelarus ADD COLUMN name varchar;
UPDATE dm2014.unibelarus SET name = 'unibelarus';
ALTER TABLE dm2014.unichina ADD COLUMN name varchar;
UPDATE dm2014.unichina SET name = 'unichina';
ALTER TABLE dm2014.dg_airbus ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus SET name = 'dg_airbus';
ALTER TABLE dm2014.dg_scanex ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex SET name = 'dg_scanex';
ALTER TABLE dm2014.dg_re ADD COLUMN name varchar;
UPDATE dm2014.dg_re SET name = 'dg_re';
ALTER TABLE dm2014.dg_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_belarus SET name = 'dg_belarus';
ALTER TABLE dm2014.dg_china ADD COLUMN name varchar;
UPDATE dm2014.dg_china SET name = 'dg_china';
ALTER TABLE dm2014.airbus_scanex ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex SET name = 'airbus_scanex';
ALTER TABLE dm2014.airbus_re ADD COLUMN name varchar;
UPDATE dm2014.airbus_re SET name = 'airbus_re';
ALTER TABLE dm2014.airbus_belarus ADD COLUMN name varchar;
UPDATE dm2014.airbus_belarus SET name = 'airbus_belarus';
ALTER TABLE dm2014.airbus_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_china SET name = 'airbus_china';
ALTER TABLE dm2014.scanex_re ADD COLUMN name varchar;
UPDATE dm2014.scanex_re SET name = 'scanex_re';
ALTER TABLE dm2014.scanex_belarus ADD COLUMN name varchar;
UPDATE dm2014.scanex_belarus SET name = 'scanex_belarus';
ALTER TABLE dm2014.scanex_china ADD COLUMN name varchar;
UPDATE dm2014.scanex_china SET name = 'scanex_china';
ALTER TABLE dm2014.re_belarus ADD COLUMN name varchar;
UPDATE dm2014.re_belarus SET name = 're_belarus';
ALTER TABLE dm2014.re_china ADD COLUMN name varchar;
UPDATE dm2014.re_china SET name = 're_china';
ALTER TABLE dm2014.belarus_china ADD COLUMN name varchar;
UPDATE dm2014.belarus_china SET name = 'belarus_china';
ALTER TABLE dm2014.dg_airbus_scanex ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex SET name = 'dg_airbus_scanex';
ALTER TABLE dm2014.dg_airbus_re ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_re SET name = 'dg_airbus_re';
ALTER TABLE dm2014.dg_airbus_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_belarus SET name = 'dg_airbus_belarus';
ALTER TABLE dm2014.dg_airbus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_china SET name = 'dg_airbus_china';
ALTER TABLE dm2014.dg_scanex_re ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_re SET name = 'dg_scanex_re';
ALTER TABLE dm2014.dg_scanex_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_belarus SET name = 'dg_scanex_belarus';
ALTER TABLE dm2014.dg_scanex_china ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_china SET name = 'dg_scanex_china';
ALTER TABLE dm2014.dg_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_re_belarus SET name = 'dg_re_belarus';
ALTER TABLE dm2014.dg_re_china ADD COLUMN name varchar;
UPDATE dm2014.dg_re_china SET name = 'dg_re_china';
ALTER TABLE dm2014.dg_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_belarus_china SET name = 'dg_belarus_china';
ALTER TABLE dm2014.airbus_scanex_re ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_re SET name = 'airbus_scanex_re';
ALTER TABLE dm2014.airbus_scanex_belarus ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_belarus SET name = 'airbus_scanex_belarus';
ALTER TABLE dm2014.airbus_scanex_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_china SET name = 'airbus_scanex_china';
ALTER TABLE dm2014.airbus_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.airbus_re_belarus SET name = 'airbus_re_belarus';
ALTER TABLE dm2014.airbus_re_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_re_china SET name = 'airbus_re_china';
ALTER TABLE dm2014.airbus_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_belarus_china SET name = 'airbus_belarus_china';
ALTER TABLE dm2014.scanex_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.scanex_re_belarus SET name = 'scanex_re_belarus';
ALTER TABLE dm2014.scanex_re_china ADD COLUMN name varchar;
UPDATE dm2014.scanex_re_china SET name = 'scanex_re_china';
ALTER TABLE dm2014.scanex_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.scanex_belarus_china SET name = 'scanex_belarus_china';
ALTER TABLE dm2014.re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.re_belarus_china SET name = 're_belarus_china';
ALTER TABLE dm2014.dg_airbus_scanex_re ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_re SET name = 'dg_airbus_scanex_re';
ALTER TABLE dm2014.dg_airbus_scanex_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_belarus SET name = 'dg_airbus_scanex_belarus';
ALTER TABLE dm2014.dg_airbus_scanex_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_china SET name = 'dg_airbus_scanex_china';
ALTER TABLE dm2014.dg_airbus_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_re_belarus SET name = 'dg_airbus_re_belarus';
ALTER TABLE dm2014.dg_airbus_re_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_re_china SET name = 'dg_airbus_re_china';
ALTER TABLE dm2014.dg_airbus_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_belarus_china SET name = 'dg_airbus_belarus_china';
ALTER TABLE dm2014.dg_scanex_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_re_belarus SET name = 'dg_scanex_re_belarus';
ALTER TABLE dm2014.dg_scanex_re_china ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_re_china SET name = 'dg_scanex_re_china';
ALTER TABLE dm2014.dg_scanex_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_belarus_china SET name = 'dg_scanex_belarus_china';
ALTER TABLE dm2014.dg_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_re_belarus_china SET name = 'dg_re_belaraus_china';
ALTER TABLE dm2014.airbus_scanex_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_re_belarus SET name = 'airbus_scanex_re_belarus';
ALTER TABLE dm2014.airbus_scanex_re_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_re_china SET name = 'airbus_scanex_re_china';
ALTER TABLE dm2014.airbus_scanex_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_belarus_china SET name = 'airbus_scanex_belarus_china';
ALTER TABLE dm2014.airbus_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_re_belarus_china SET name = 'airbus_re_belarus_china';
ALTER TABLE dm2014.scanex_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.scanex_re_belarus_china SET name = 'scanex_re_belarus_china';
ALTER TABLE dm2014.dg_airbus_scanex_re_belarus ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_re_belarus SET name = 'dg_airbus_scanex_re_belarus';
ALTER TABLE dm2014.dg_airbus_scanex_re_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_re_china SET name = 'dg_airbus_scanex_re_china';
ALTER TABLE dm2014.dg_airbus_scanex_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_belarus_china SET name = 'dg_airbus_scanex_belarus_china';
ALTER TABLE dm2014.dg_airbus_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_re_belarus_china SET name = 'dg_airbus_re_belarus_china';
ALTER TABLE dm2014.dg_scanex_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_scanex_re_belarus_china SET name = 'dg_scanex_re_belarus_china';
ALTER TABLE dm2014.airbus_scanex_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.airbus_scanex_re_belarus_china SET name = 'airbus_scanex_re_belarus_china';
ALTER TABLE dm2014.dg_airbus_scanex_re_belarus_china ADD COLUMN name varchar;
UPDATE dm2014.dg_airbus_scanex_re_belarus_china SET name = 'dg_airbus_scanex_re_belarus_china';

/* Таблица результатов */
CREATE TABLE results
             (name varchar(250), sqkm int, perc int)

/* Считаем площадь AOI */
SELECT SUM(ST_Area(dm2014.merge_aoi.geom)/1000000) from dm2014.merge_aoi;

INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.unidg
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.uniairbus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.uniscanex
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.unire
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.unibelarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.unichina
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.merge_dg
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.merge_airbus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.merge_scanex
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.merge_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.merge_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.merge_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_re
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.scanex_re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_re_belarus
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_re_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_scanex_re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.airbus_scanex_re_belarus_china
   GROUP BY "name");
INSERT INTO results
    (SELECT "name", SUM(ST_Area(geom))/1000000, (SUM(ST_Area(geom))/1000000)/8775.57326180735
       FROM dm2014.dg_airbus_scanex_re_belarus_china
   GROUP BY "name");