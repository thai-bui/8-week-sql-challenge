# 🍽️ Case Study 1: Danny's Diner SQL Challenge Solutions

This repository contains the setup, solutions, and business insights for **Case Study 1: Danny's Diner** of the Danny Ma **#8WeekSQLChallenge**.

---

## 🎯 Project Goal
Danny’s Diner is sitting on raw data that's currently useless to him. I’m using PostgreSQL to strip away the noise and find out exactly who is spending money, how much they are spending and what they’re eating. This exercise about finding the specific insights Danny needs to stop guessing and start making data-driven decisions about his loyalty program and daily operations.

---

## 🛠️ Repository Contents

| File / Folder | Purpose |
|---------------|----------|
| **setup.sql** | Contains DDL (CREATE TABLE) and DML (INSERT) statements to fully recreate the database schema and data set for Danny's Diner. |
| **solutions.sql** | Contains the SQL queries for all 10 challenge questions (plus bonus questions) and the raw data output as comments below each query. Additional documentation for specific answers are also included under each question. |
| **insights.md (Current File)** | Contains the detailed business analysis and summarized findings derived from the SQL results. |

---

## 📈 Analytical Insights Summary

### 1. Customer Spending and Frequency
The customer base shows a clear spending tier, with Customer A ($76) and Customer B ($74) established as the top-tier spenders, with each of the customers spending double Customer C’s total spend ($36). Customer B went to the restaurant most times, 50% more times than Customer A, and three times that of Customer C. Thus, Customer A has a significantly higher average spending habit per visit. This is likely influenced by consumption volume or their successful effort to maximize rewards during the initial promotional period. Customer C may need incentives provided to increase their spending for retention purposes.

---

### 2. Product Popularity and Loyalty
The most popular item on the menu for all customers is ramen, with it being ordered over 50% of all sales. Seems like whatever recipe Danny has prepared for ramen is successful and its quality should remain unchanged. In addition, this could be cost-driven since ramen is the cheapest item at $12. Danny should make sure that it is a core part of the menu and be visible through appropriate menu designs. Danny could survey existing customers on how they feel about the remaining items and reasons why it might not be as popular to understand their decision-making as well as experiment with creating a combo meal with ramen, the current popular item.

---

### 3. Membership Status and Behavioral Trends
Customer A and C have a soft spot for ramen, with it being their most popular purchase. Customer B, however, likes to change around what they order as they have ordered all items the same number of times. Danny could try to explore whether the purchase motive is driven by cost, background, or preference. Right before being a member, both Customer A and B bought sushi. Before becoming a member, Customer B bought more items and spent 60% more money than Customer A.

---

### 4. Promotional Responsiveness
After becoming a member, Customer A capitalized more on the special member rewards program and accumulated almost double the number of points than Customer B by the end of January. Across the sample, both Customer A and B made the same number of total purchases (6 purchases). However, 50% of items purchased from Customer A happened during the first week of them becoming a member (compared to Customer B’s 33.3%). This disparity suggests Customer B was not as “sensitive” with special program perks, as their visits are more spread out and consistent. This pattern strongly indicates that Customer A is a value-driven customer who acts immediately on incentives.

