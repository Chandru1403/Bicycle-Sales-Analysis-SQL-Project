CREATE DATABASE sales_analysis;

USE sales_analysis;

-- Managing Relationship between across all the tables

SELECT * FROM customers;
DESCRIBE customers;
ALTER TABLE customers ADD CONSTRAINT PRIMARY KEY (customerkey);

SELECT * FROM product;
DESCRIBE product;
ALTER TABLE  product ADD CONSTRAINT PRIMARY KEY (productkey);

SELECT * FROM product_categories;
DESCRIBE product_categories;
ALTER TABLE  product_categories ADD CONSTRAINT PRIMARY KEY (productcategorykey);

SELECT * FROM product_subcategories;
DESCRIBE product_subcategories;
ALTER TABLE product_subcategories ADD CONSTRAINT PRIMARY KEY (productsubcategorykey);
ALTER TABLE  product_subcategories ADD CONSTRAINT FOREIGN KEY (productcategorykey) REFERENCES product_categories (productcategorykey);

SELECT * FROM returns_data;
DESCRIBE returns_data;
ALTER TABLE returns_data ADD CONSTRAINT FOREIGN KEY (productkey) REFERENCES product (productkey) ;

SELECT * FROM territory_lookup;
DESCRIBE territory_lookup;
ALTER TABLE territory_lookup ADD CONSTRAINT PRIMARY KEY (salesterritorykey);

ALTER TABLE returns_data ADD CONSTRAINT FOREIGN KEY (territorykey) REFERENCES territory_lookup (salesterritorykey) ;

UPDATE customers
SET Title = concat(title," ",Firstname," ",SecondName);

ALTER TABLE customers DROP COLUMN Firstname;
ALTER TABLE customers DROP COLUMN Secondname;
ALTER TABLE customers CHANGE `title` `Name` VARCHAR(100);



SELECT * FROM sales_2021;
SELECT * FROM sales_2022;
SELECT * FROM sales_2020;

-- Combine three sales tables into one.

CREATE TABLE sales (
         OrderDate DATE,
         StockDate DATE,
         OrderNumber VARCHAR(15),
         ProductKey INT,
         CustomerKey INT,
         TerritoryKey INT,
         OrderLineItem INT,
         OrderQuantity INT,
         FOREIGN KEY (ProductKey) REFERENCES product (ProductKey),
         FOREIGN KEY (CustomerKey) REFERENCES customers (CustomerKey),
         FOREIGN KEY (TerritoryKey) REFERENCES territory_lookup (salesterritorykey)
         
);




INSERT INTO sales (

                    SELECT * FROM sales_2020
                    UNION
                    SELECT * FROM sales_2021 
                    UNION
                    SELECT * FROM sales_2022
				);




DESCRIBE customers;

-- Sales & Revenue Analysis


-- 1. Top 3 Regions by Number of Orders

SELECT 
       territorykey,
       t.region,
       count(OrderNumber) AS TotalOrders
FROM sales
JOIN territory_lookup AS t
     ON sales.territorykey = t.salesterritorykey
GROUP BY territorykey
ORDER BY count(OrderNumber) DESC
LIMIT 3; 

-- 2. Find the top 5 most profitable products along with sub category Name

SELECT 
      s.productkey,
      pc.categoryname,
      ps.subcategoryname ,
      p.productname,
      round(sum((s.productprice - p.productcost) * s.orderquantity ),0) as Totalprofit
FROM sales AS s
JOIN product AS p
     ON s.productkey = p.productkey
JOIN product_subcategories AS ps
     ON p.productsubcategorykey = ps.productsubcategorykey
JOIN product_categories as pc
     ON ps.productcategorykey = pc.productcategorykey
GROUP BY s.productkey, pc.categoryname, ps.subcategoryname , p.productname
ORDER BY Totalprofit DESC
LIMIT 5;

SELECT * FROM product_subcategories;
SELECT * FROM returns_data;
SELECT * FROM customers;
SELECT * FROM sales;
SELECT * FROM product_categories;
SELECT * FROM product;
SELECT * FROM territory_lookup;
SELECT * FROM returns_data;

-- 3. Profit Margin by Product Category

SELECT
	  pc.categoryname,
      round( sum((s.productprice - p.productcost) * s.orderquantity),0) AS TotalProfit,
	  round(sum((s.productprice - p.productcost) * s.orderquantity) / sum(s.totalamount) * 100 ,0) AS Profitmargin
FROM sales AS s
JOIN product AS p
     ON s.productkey = p.productkey
JOIN product_subcategories AS ps
     ON p.productsubcategorykey = ps.productsubcategorykey
JOIN product_categories as pc
     ON ps.productcategorykey =  pc.productcategorykey
GROUP BY pc.categoryname;


-- 4. Top 10 Customers by Total Profit

SELECT 
    s.customerkey,
    c.Name,
    ROUND(SUM((s.productprice - p.productcost) * s.orderquantity),0) AS TotalProfit
FROM sales AS s
JOIN customers AS c 
    ON s.customerkey = c.customerkey
JOIN product AS p 
    ON s.productkey = p.productkey
GROUP BY s.customerkey, c.Name
ORDER BY TotalProfit DESC
LIMIT 10;


-- 2. What is the total revenue generated per product category per year?

SELECT 
	   c.categoryname ,
       extract( year from s.orderdate) AS Year,
      round(sum((s.orderquantity *p.productprice)),0)  AS sales
FROM product_categories as c
JOIN product_subcategories  AS ps
     ON c.productcategorykey = ps.productcategorykey 
JOIN product as p
     ON ps.productsubcategorykey = p.productsubcategorykey 
JOIN sales AS s 
     ON p.productkey  = s.productkey  
GROUP BY  c.categoryname, extract( year from s.orderdate)
ORDER BY c.categoryname,Year ;


-- 3. Which product generated the highest total revenue in each region?

UPDATE territory_lookup
SET region = concat(region," - US")
WHERE country = "United States";

 
 WITH regionsales AS (
 
	  SELECT 
             t.region AS region,
             p.productname AS productName,
             round(sum(s.orderquantity * p.productprice),0) as revenue,
             RANK() OVER( PARTITION BY t.region ORDER BY  sum(s.orderquantity * p.productprice) DESC) as ranks
			FROM territory_lookup AS t
            JOIN sales AS s
                 ON t.salesterritorykey = s.territorykey
            JOIN product AS p
                 ON s.productkey = p.productkey
            GROUP BY  t.region,p.productname 
)

SELECT region ,
	   productname, 
       revenue 
FROM regionsales
where ranks = 1
ORDER BY revenue DESC ;


-- 4. What is the average order quantity per customer per year?

SELECT  
      s.customerkey,
      c.Name,
      extract( YEAR FROM s.orderdate) as Year,
      round(AVG(s.orderquantity),1) as AverageOrder
FROM sales as s
JOIN customers as c
     ON s.customerkey = c.customerkey 
GROUP BY s.customerkey, extract( YEAR FROM s.orderdate) 
ORDER BY s.customerkey, extract( YEAR FROM s.orderdate);

 -- 11.List all products that never appear in the Sales table
 
 SELECT  
	   p.productkey,
       p.productname,
       s.productkey
FROM product as p
LEFT JOIN sales as s
     ON p.productkey = s.productkey
WHERE s.productkey IS NULL;


-- 5. Find the top 5 products with the highest return quantity.

SELECT 
       r.productkey,
       p.productname,
       sum(r.returnquantity)as returnqty
FROM returns_data as r
JOIN product as p
     ON p.productkey = r.productkey
GROUP BY r.productkey,p.productname
ORDER BY returnqty DESC
LIMIT 5;



-- 6. What is the monthly sales trend for each product subcategory?

SELECT 
      ps.subcategoryName,
      extract(month from s.orderdate) AS Month,
      extract(Year from s.orderdate) AS year,
      round(sum(p.productprice * s.orderquantity),0) as sales
      
FROM product_subcategories as ps
JOIN product AS p
     ON  ps.productsubcategorykey = p.productsubcategorykey
JOIN sales AS s
     ON  p.productkey = s.productkey
GROUP BY  ps.subcategoryName,extract(Year from s.orderdate),extract(month from s.orderdate) 
ORDER BY ps.subcategoryName,month,year;




-- Adding productprice and total sales column in sales table

ALTER TABLE sales ADD COLUMN ProductPrice DECIMAL(10,5);
ALTER TABLE sales ADD COLUMN sales DECIMAL(10,5);
ALTER TABLE sales CHANGE `sales` `TotalAmount` DECIMAL(10,5);

SET SQL_SAFE_UPDATES = 0;

UPDATE sales
SET productprice = ( SELECT p.productprice FROM product AS p
					WHERE p.productkey = sales.productkey);
                    
UPDATE sales
SET  TotalAmount = ( OrderQuantity * ProductPrice) ;


-- 7. Which occupation group contributes the most to total revenue?

SELECT 
      c.Occupation,
      sum(s.TotalAmount) as TotalAmount
FROM customers AS c
JOIN sales AS s
     ON c.customerkey = s.customerkey
GROUP BY c.Occupation 
ORDER BY TotalAmount DESC;


-- 8. List the top 10 customers by total order quantity and their average order size.


WITH topcustomer AS (
SELECT
      s.customerkey,
      c.Name,
      sum(orderquantity) AS TotalOrderQuantity,
      avg(orderquantity) AS AverageOrderQuantity,
      RANK() OVER (order by sum(orderquantity) DESC ) as ranks
      
FROM customers AS c
JOIN sales AS s
     ON c.customerkey = s.customerkey
GROUP BY s.customerkey,c.Name
ORDER BY TotalOrderQuantity  DESC, AverageOrderQuantity DESC

)
SELECT * FROM topcustomer
where ranks <=10;


-- 9. Which region has the highest return quantity?

SELECT 
       r.Territorykey,
       t.region,
       SUM(r.returnquantity) TotalReturnQty
FROM returns_data AS r
JOIN territory_lookup AS t
     ON r.Territorykey = t.salesterritorykey
GROUP BY r.Territorykey
ORDER BY TotalReturnQty DESC
LIMIT 1;


-- 10 .Find the top 3 customers in each region based on total sales amount

WITH Regiontopcustomer AS (

SELECT 
       s.territorykey,
       s.customerkey,
       t.region,
       c.name,
       round(sum(s.totalamount),0) AS TotalAmount,
       RANK() OVER(PARTITION BY t.region ORDER BY sum(s.totalamount) DESC) AS Ranks
FROM  sales AS s
JOIN territory_lookup as t
     ON s.territorykey = t.salesterritorykey
JOIN customers AS c
     ON s.customerkey = c.customerkey
GROUP BY s.territorykey, s.customerkey ,t.region,c.name
)

SELECT * FROM Regiontopcustomer
WHERE ranks <= 3;


-- 12. Find products whose total sales amount is less than the average sales amount of all products.

SELECT
      productkey,
      sum(totalamount) AS TotalSales
FROM sales
GROUP BY productkey
HAVING sum(totalamount) < (select avg(total) from 
                                                 (SELECT 
                                                        productkey,
								                        sum(totalamount) as total
                                                  FROM sales
                                                  GROUP BY productkey) as a );
                                                  
                                                  
-- 13 . Find products that had at least one sale in every month of 2021

    
    SELECT 
    p.productkey,
    p.productname
FROM product AS p
WHERE p.productkey IN  (
                         SELECT 
                                s.productkey
                         FROM sales AS s
                         WHERE extract(YEAR FROM s.orderdate) = 2021
                         GROUP BY s.productkey
						HAVING count(DISTINCT extract(MONTH FROM s.orderdate)) = 12
) ;



-- 14. Find the territory with the highest total revenue.

WITH revenue_territory AS (
                           SELECT 
                                    
                                    s.Territorykey,
                                    t.region,
                                    extract(year FROM s.Orderdate) AS Year,
									round(sum(s.totalamount),0) as TotalRevenue,
									RANK() OVER(PARTITION BY extract(year FROM s.Orderdate) ORDER BY sum(s.totalamount) DESC) AS Ranks
                          FROM sales AS s
                          JOIN territory_lookup AS t
                               ON s.territorykey = t.salesterritorykey
						  GROUP BY territorykey, extract(year FROM Orderdate),t.region
                          )
                          
                          
SELECT * FROM revenue_territory 
WHERE Ranks =1 ;







 
