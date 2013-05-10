CREATE OR REPLACE TYPE U_CIRCULAR_AVG AS OBJECT
(
  running_sum_cos_n NUMBER, -- a running sum of the cosine of the numbers passed
  running_sum_sin_n NUMBER, -- a running sum of the sine of the numbers passed
  running_count NUMBER, -- a count of the numbers passed
  STATIC FUNCTION ODCIAggregateInitialize(sctx IN OUT U_CIRCULAR_AVG) RETURN NUMBER,
  MEMBER FUNCTION ODCIAggregateIterate(self IN OUT U_CIRCULAR_AVG, value IN NUMBER) RETURN NUMBER,
  MEMBER FUNCTION ODCIAggregateTerminate(self IN U_CIRCULAR_AVG, returnValue OUT NUMBER, flags IN NUMBER) RETURN NUMBER,
  MEMBER FUNCTION ODCIAggregateMerge(self IN OUT U_CIRCULAR_AVG, ctx2 IN U_CIRCULAR_AVG) RETURN NUMBER
);

CREATE OR REPLACE TYPE BODY U_CIRCULAR_AVG IS
  STATIC FUNCTION ODCIAggregateInitialize(sctx IN OUT U_CIRCULAR_AVG) RETURN NUMBER IS
  BEGIN
    SCTX := U_CIRCULAR_AVG(0, 0, 0);
    RETURN ODCIConst.Success;
  END;

  -- Iterate over the input values. 
  -- The input is accepted in degrees and converted to radians for the SIN() and COS() functions.
  MEMBER FUNCTION ODCIAggregateIterate(self IN OUT U_CIRCULAR_AVG, value IN NUMBER) RETURN NUMBER IS
  BEGIN
    SELF.running_sum_cos_n := SELF.running_sum_cos_n + COS(value*3.14159265359/180);
    SELF.running_sum_sin_n := SELF.running_sum_sin_n + SIN(value*3.14159265359/180);
    SELF.running_count := SELF.running_count + 1;
    RETURN ODCIConst.Success;
  END;

  -- When all values have been processed, we just calculate the averages and pass to ATAN2().
  -- The result is normalised to within range 0 to 359.999999 and converted back to degrees.
  MEMBER FUNCTION ODCIAggregateTerminate(self IN U_CIRCULAR_AVG, returnValue OUT NUMBER, flags IN NUMBER) RETURN NUMBER IS
    avg_c number;
    avg_s number;
    n number;
  BEGIN
    avg_c := SELF.running_sum_cos_n / SELF.running_count;
    avg_s := SELF.running_sum_sin_n / SELF.running_count;
    n := ATAN2(avg_s, avg_c) * 180 / 3.14159265359;
    
    IF n >= 0 THEN
      returnValue := n;
    ELSE 
      returnValue := n + 360;
    END IF;
    
    RETURN ODCIConst.Success;
  END;
  
  MEMBER FUNCTION ODCIAggregateMerge(self IN OUT U_CIRCULAR_AVG, ctx2 IN U_CIRCULAR_AVG) RETURN NUMBER IS
  BEGIN
    SELF.running_sum_cos_n := SELF.running_sum_cos_n + ctx2.running_sum_cos_n;
    SELF.running_sum_sin_n := SELF.running_sum_sin_n + ctx2.running_sum_sin_n;
    SELF.running_count := SELF.running_count + ctx2.running_count;
    RETURN ODCIConst.Success;
  END;
END;

CREATE FUNCTION CIRCULAR_AVG (input NUMBER) RETURN NUMBER PARALLEL_ENABLE AGGREGATE USING U_CIRCULAR_AVG;
