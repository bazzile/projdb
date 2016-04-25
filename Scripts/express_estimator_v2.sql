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

/* На этом этапе мы фильтруем coverage_all в соответствии с требованиями*/

/* Сначала узнаем, какие спутники есть в подборке */
SELECT DISTINCT satname
  FROM dm2014.coverage_all;

-- Время выполнения

/* Создаём объединённую таблицу AOI для ускорения последующей обработки*/
CREATE TABLE dm2014.merge_aoi AS
     (SELECT ST_Union(dm2014.aoi.geom) AS geom
        FROM dm2014.aoi);

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

-- Время выполнения: 31.2 secs



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