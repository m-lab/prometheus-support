#standardSQL

CREATE TEMP FUNCTION EncodeGeoHASH(latitude FLOAT64, longitude FLOAT64, hashLength INT64)
RETURNS STRING
LANGUAGE js AS """
/**
 * Function sources derived from node-geohash library:
 * https://github.com/sunng87/node-geohash/blob/master/main.js
 *
 * Copyright (c) 2011, Sun Ning.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
var BASE32_CODES = "0123456789bcdefghjkmnpqrstuvwxyz";
var SIGFIG_HASH_LENGTH = [0, 5, 7, 8, 11, 12, 13, 15, 16, 17, 18];
function encodeGeohash(latitude, longitude) {
  var numberOfChars = hashLength;

  var chars = [],
  bits = 0,
  bitsTotal = 0,
  hash_value = 0,
  maxLat = 90,
  minLat = -90,
  maxLon = 180,
  minLon = -180,
  mid;
  while (chars.length < numberOfChars) {
    if (bitsTotal % 2 === 0) {
      mid = (maxLon + minLon) / 2;
      if (longitude > mid) {
        hash_value = (hash_value << 1) + 1;
        minLon = mid;
      } else {
        hash_value = (hash_value << 1) + 0;
        maxLon = mid;
      }
    } else {
      mid = (maxLat + minLat) / 2;
      if (latitude > mid) {
        hash_value = (hash_value << 1) + 1;
        minLat = mid;
      } else {
        hash_value = (hash_value << 1) + 0;
        maxLat = mid;
      }
    }

    bits++;
    bitsTotal++;
    if (bits === 5) {
      var code = BASE32_CODES[hash_value];
      chars.push(code);
      bits = 0;
      hash_value = 0;
    }
  }
  return chars.join('');
};
return encodeGeohash(latitude, longitude);
""";
SELECT
  metro, site, geohash, value_tests
FROM
(
  SELECT
    MAX(REGEXP_EXTRACT(connection_spec.server_hostname, r"mlab[1-4].([a-z]{3})[0-9]{2}.*")) as metro,
    REGEXP_EXTRACT(connection_spec.server_hostname, r"mlab[1-4].([a-z]{3}[0-9]{2}).*") as site,
    COUNT(*) AS value_tests
  FROM
    `measurement-lab.ndt_raw.web100_legacy`
  WHERE
        -- For faster queries we use `partition_date` boundaries. And, to
        -- guarantee the partition_date data is "complete" (all data collected
        -- and parsed) we should wait 36 hours after start of a given day.
        -- The following is equivalent to the pseudo code: date(now() - 12h) - 1d
    partition_date = DATE(TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR))
    -- Basic test quality filters for safe division.
    AND web100_log_entry.snap.Duration > 0
    AND (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) > 0
    AND web100_log_entry.snap.CountRTT > 0
    AND web100_log_entry.snap.HCThruOctetsReceived > 0
    AND web100_log_entry.snap.HCThruOctetsAcked > 0
  GROUP BY
    site
  HAVING
    value_tests > 10
    AND site IS NOT NULL

) JOIN (
  -- metro to geohash.
  SELECT
    REGEXP_EXTRACT(connection_spec.server_hostname, r"mlab[1-4].([a-z]{3})[0-9]{2}.*") as metro,
    MIN(EncodeGeoHASH(connection_spec.server_geolocation.latitude, connection_spec.server_geolocation.longitude, 5)) AS geohash
  FROM
    `measurement-lab.base_tables.ndt`
  WHERE
    -- For faster queries we use `partition_date` boundaries. And, to
    -- guarantee the partition_date data is "complete" (all data collected
    -- and parsed) we should wait 36 hours after start of a given day.
    -- The following is equivalent to the pseudo code: date(now() - 12h) - 1d
    partition_date = DATE(TIMESTAMP_SUB(TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR), DAY), INTERVAL 24 HOUR))
  GROUP BY
    metro
  HAVING
    geohash IS NOT NULL

) USING (metro)
