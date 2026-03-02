CREATE DATABASE supply_chain_dw;
USE supply_chain_dw;
show tables;
drop database supply_chain_dw ;

select count(*) from  customer;
select count(*) from  product;
select count(*) from  supplier;
select count(*) from  warehouse;
select count(*) from  purchase;
select count(*) from  sales;
select count(*) from  shipment;
select count(*) from  inventory;

ALTER TABLE shipment ENGINE=InnoDB;
ALTER TABLE sales ENGINE=InnoDB;
ALTER TABLE inventory ENGINE=InnoDB;
ALTER TABLE purchase ENGINE=InnoDB;

ALTER TABLE customer MODIFY Customer_ID VARCHAR(20);
ALTER TABLE product MODIFY Product_ID VARCHAR(20);
ALTER TABLE warehouse MODIFY Warehouse_ID VARCHAR(20);
ALTER TABLE supplier MODIFY Supplier_ID VARCHAR(20);

ALTER TABLE sales MODIFY Customer_ID VARCHAR(20);
ALTER TABLE sales MODIFY Product_ID VARCHAR(20);

ALTER TABLE shipment MODIFY Sales_Order_ID VARCHAR(20);
ALTER TABLE shipment MODIFY Warehouse_ID VARCHAR(20);

ALTER TABLE inventory MODIFY Warehouse_ID VARCHAR(20);
ALTER TABLE inventory MODIFY Product_ID VARCHAR(20);

ALTER TABLE purchase MODIFY Supplier_ID VARCHAR(20);
ALTER TABLE purchase MODIFY Product_ID VARCHAR(20);




ALTER TABLE customer ADD PRIMARY KEY (Customer_ID);
ALTER TABLE product ADD PRIMARY KEY (Product_ID);
ALTER TABLE warehouse ADD PRIMARY KEY (Warehouse_ID);
ALTER TABLE supplier ADD PRIMARY KEY (Supplier_ID);

ALTER TABLE sales ADD PRIMARY KEY (Sales_Order_ID);
ALTER TABLE shipment ADD PRIMARY KEY (Shipment_ID);
ALTER TABLE inventory ADD PRIMARY KEY (Inventory_ID);
ALTER TABLE purchase ADD PRIMARY KEY (PO_ID);


ALTER TABLE sales MODIFY Sales_Order_ID VARCHAR(20);
ALTER TABLE shipment MODIFY Shipment_ID VARCHAR(20);
ALTER TABLE inventory MODIFY Inventory_ID VARCHAR(20);
ALTER TABLE purchase MODIFY PO_ID VARCHAR(20);

SELECT PO_ID, COUNT(*)
FROM purchase
GROUP BY PO_ID
HAVING COUNT(*) > 1;

ALTER TABLE sales ADD PRIMARY KEY (Sales_Order_ID);
ALTER TABLE shipment ADD PRIMARY KEY (Shipment_ID);
ALTER TABLE inventory ADD PRIMARY KEY (Inventory_ID);
ALTER TABLE purchase ADD PRIMARY KEY (PO_ID);

SHOW KEYS FROM product;
SHOW KEYS FROM warehouse;
SHOW KEYS FROM supplier;
SHOW KEYS FROM sales;
SHOW KEYS FROM shipment;
SHOW KEYS FROM inventory;
SHOW KEYS FROM purchase;

-- Quick Orphan Check (RUN FIRST — prevents FK failure) 
-- Sales → Customer 
SELECT COUNT(*)
FROM sales s
LEFT JOIN customer c
  ON s.Customer_ID = c.Customer_ID
WHERE c.Customer_ID IS NULL;
-- Sales → Product 
SELECT COUNT(*)
FROM sales s
LEFT JOIN product p
  ON s.Product_ID = p.Product_ID
WHERE p.Product_ID IS NULL;

-- Shipment → Sales
SELECT COUNT(*)
FROM shipment sh
LEFT JOIN sales s
  ON sh.Sales_Order_ID = s.Sales_Order_ID
WHERE s.Sales_Order_ID IS NULL;

-- Inventory → Warehouse
SELECT COUNT(*)
FROM inventory i
LEFT JOIN warehouse w
  ON i.Warehouse_ID = w.Warehouse_ID
WHERE w.Warehouse_ID IS NULL;

-- Purchase → Supplier
SELECT COUNT(*)
FROM purchase p
LEFT JOIN supplier s
  ON p.Supplier_ID = s.Supplier_ID
WHERE s.Supplier_ID IS NULL;   

-- FOREIGN KEY CREATION (RUN IN ORDER)
-- Sales → Customer
ALTER TABLE sales
ADD CONSTRAINT fk_sales_customer
FOREIGN KEY (Customer_ID)
REFERENCES customer(Customer_ID);
-- Sales → Product
ALTER TABLE sales
ADD CONSTRAINT fk_sales_product
FOREIGN KEY (Product_ID)
REFERENCES product(Product_ID);

-- SHIPMENT TABLE LINKS
-- Shipment → Sales
ALTER TABLE shipment
ADD CONSTRAINT fk_shipment_sales
FOREIGN KEY (Sales_Order_ID)
REFERENCES sales(Sales_Order_ID);
-- Shipment → Warehouse
ALTER TABLE shipment
ADD CONSTRAINT fk_shipment_warehouse
FOREIGN KEY (Warehouse_ID)
REFERENCES warehouse(Warehouse_ID);

-- INVENTORY TABLE LINKS
-- Inventory → Warehouse
ALTER TABLE inventory
ADD CONSTRAINT fk_inventory_warehouse
FOREIGN KEY (Warehouse_ID)
REFERENCES warehouse(Warehouse_ID);

-- Inventory → Product
ALTER TABLE inventory
ADD CONSTRAINT fk_inventory_product
FOREIGN KEY (Product_ID)
REFERENCES product(Product_ID);

-- PURCHASE TABLE LINKS
--  Purchase → Supplier
ALTER TABLE purchase
ADD CONSTRAINT fk_purchase_supplier
FOREIGN KEY (Supplier_ID)
REFERENCES supplier(Supplier_ID);

-- Purchase → Product
ALTER TABLE purchase
ADD CONSTRAINT fk_purchase_product
FOREIGN KEY (Product_ID)
REFERENCES product(Product_ID);       

-- BUSINESS SQL INSIGHTS
--  1. What is the overall On-Time Delivery (OTIF) performance??  
SELECT
ROUND(SUM(CASE  WHEN DELAY_FLAG = 0 THEN 1 ELSE 0 END ) / COUNT(*) ,2) *100  AS OTIF_Percentage FROM SHIPMENT;

-- 2. Which transport mode has the highest delay risk?
SELECT 
TRANSPORT_MODE ,
ROUND(AVG(DELAY_FLAG)*100  ,2) AS  Delay_Percentage  FROM SHIPMENT
GROUP BY TRANSPORT_MODE 
ORDER BY Delay_Percentage DESC;

-- 3. Which routes have the worst average transit time?
SELECT 
W.COUNTRY AS ORIGIN_COUNTRY,
C.REGION AS DESTINATION_REGION,
ROUND(AVG(SH.TRANSIT_TIME)/ (1000000000 * 60 * 60 * 24)) AS AVG_TRANSIT_TIME_DAYS ,
COUNT(SH.SHIPMENT_ID)AS SHIPMENT_COUNT
FROM SHIPMENT SH
-- ORIGIN_COUNTRY TO SHIPMENT
JOIN WAREHOUSE W 
ON W.WAREHOUSE_ID  = SH.WAREHOUSE_ID 
-- SHIPMENT  TO SALES 
JOIN SALES SA
ON SH.SALES_ORDER_ID = SA.SALES_ORDER_ID
-- SALES  TO CUSTOMERS
JOIN CUSTOMER C
ON SA.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY W.COUNTRY ,C.REGION 
LIMIT 10;

-- 4. Which customers generate the highest revenue? 
SELECT 
	C.CUSTOMER_ID,
	C.CUSTOMER_NAME ,
    C.CUSTOMER_TYPE ,
    C.INDUSTRY ,
    SUM(S.ORDER_VALUE) AS REVENUE
FROM CUSTOMER C
INNER JOIN SALES S
ON C.CUSTOMER_ID = S.CUSTOMER_ID 
GROUP BY C.CUSTOMER_NAME ,C.CUSTOMER_TYPE , C.INDUSTRY ,C.CUSTOMER_ID
ORDER BY REVENUE DESC
LIMIT 10 ;

-- 5. Which warehouses handle the most shipments? 
SELECT
	W.WAREHOUSE_ID ,
    W.WAREHOUSE_NAME ,
    COUNT(SH.SHIPMENT_ID) AS NUMBER_OF_SHIPMENTS 
FROM SHIPMENT SH
JOIN WAREHOUSE W
ON W.WAREHOUSE_ID = SH.WAREHOUSE_ID
GROUP BY W.WAREHOUSE_ID ,W.WAREHOUSE_NAME 
ORDER BY NUMBER_OF_SHIPMENTS DESC;

-- 6. Detect warehouses with inventory mismatch issues
     SELECT 
		W.WAREHOUSE_NAME ,
        SUM(I.STOCK_MISMATCH_FLAG) AS ISSUE_COUNT
	FROM INVENTORY I 
    JOIN WAREHOUSE W
    ON W.WAREHOUSE_ID = I.WAREHOUSE_ID
    GROUP BY W.WAREHOUSE_NAME;
-- 7. What is the average profit margin by transport mode?
ALTER TABLE shipment
RENAME COLUMN `PROFIT_MARGIN_%` TO PROFIT_MARGIN;	
	 SELECT 
		SH.TRANSPORT_MODE ,
		ROUND(AVG(SH.PROFIT_MARGIN),2) AS AVERAGE_PROFIT_MARGIN
     FROM SHIPMENT SH
     GROUP BY SH.TRANSPORT_MODE 
     ORDER BY AVERAGE_PROFIT_MARGIN DESC;
     
	-- 8. Monthly sales trend
    SELECT 
		DATE_FORMAT(ORDER_DATE , '%Y-%M') AS ORDER_MONTH,
        SUM(ORDER_VALUE) AS MONTHLY_REVENUE
	FROM SALES 
    GROUP BY ORDER_MONTH 
    ORDER BY MONTHLY_REVENUE DESC;
    
    -- 9.Top customers with poor delivery performance 
    SELECT
    C.CUSTOMER_NAME,
    SUM(S.ORDER_VALUE) AS REVENUE,
    ROUND(AVG(SH.DELAY_FLAG) * 100, 2) AS DELAY_PERCENTAGE
FROM SALES S
JOIN SHIPMENT SH
    ON S.SALES_ORDER_ID = SH.SALES_ORDER_ID
JOIN CUSTOMER C
    ON S.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY C.CUSTOMER_NAME
-- REVENUE > 50000 CONSIDER 
HAVING REVENUE > 50000
ORDER BY DELAY_PERCENTAGE DESC;

-- 10. Warehouse load ranking 
    SELECT WAREHOUSE_ID,
   ROUND( AVG(WAREHOUSE_LOAD_INDEX) ,2)AS AVG_LOD, 
    DENSE_RANK() 
    OVER( ORDER BY AVG(WAREHOUSE_LOAD_INDEX) DESC ) AS RANKS
    FROM INVENTORY
    GROUP BY WAREHOUSE_ID;
-- 11. Top 5 most expensive shipments 
SELECT *
FROM (
    SELECT
        SHIPMENT_ID,
        TOTAL_SHIPPING_COST,
        RANK() OVER (ORDER BY TOTAL_SHIPPING_COST DESC) AS COST_RANK
    FROM SHIPMENT
) T
WHERE COST_RANK <= 5;

-- 12. Customer segment revenue contribution
SELECT
    C.CUSTOMER_TYPE,
    SUM(S.ORDER_VALUE) AS TOTAL_REVENUE
FROM SALES S
JOIN CUSTOMER C
    ON S.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY C.CUSTOMER_TYPE
ORDER BY TOTAL_REVENUE DESC;

-- 13.Fast vs slow fulfillment distribution
SELECT
    FULFILLMENT_SPEED,
    COUNT(*) AS SHIPMENT_COUNT,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS PERCENTAGE
FROM SHIPMENT
GROUP BY FULFILLMENT_SPEED
ORDER BY SHIPMENT_COUNT DESC;
-- 14. Products with highest inventory throughput
SELECT
    P.PRODUCT_NAME,
    SUM(I.THROUGHPUT) AS TOTAL_THROUGHPUT
FROM INVENTORY I
JOIN PRODUCT P
    ON I.PRODUCT_ID = P.PRODUCT_ID
GROUP BY P.PRODUCT_NAME
ORDER BY TOTAL_THROUGHPUT DESC
LIMIT 10;
 
     
     

	 

select * from  customer;
select * from  product;
select * from  supplier;
select * from  warehouse;
select * from  purchase;
select * from  sales;
select * from  shipment;
select * from  inventory;

