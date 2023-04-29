-- When importing a CSV file, Azure did not allow for changing the format, so the Derived Columns were created for SaleDate and SalePrice

SELECT *
FROM Nashville

-- Along the way we make sure that UniqueID is actually unique (the number of total rows and the number of rows returned by following is the same)
SELECT DISTINCT UniqueID 
FROM Nashville

-- Drop original SaleDate column and convert the Derived SaleDate1 to date format
ALTER TABLE Nashville
DROP COLUMN SaleDate

UPDATE Nashville
SET SaleDate1 = CONVERT(date, SaleDate1)

--Fill missing Property Addresses
-- Going through the data, we see that ParcelID and PropertyAddress are related 
SELECT *
FROM Nashville
WHERE PropertyAddress IS NULL

--SELECT ParcelID, PropertyAddress
--FROM Nashville
--WHERE PropertyAddress IS NULL

SELECT x.ParcelID, x.PropertyAddress, y.ParcelID, y.PropertyAddress, ISNULL(y.PropertyAddress, x.PropertyAddress) AddressPopulated
FROM Nashville x
JOIN Nashville y
    ON x.ParcelID = y.ParcelID
    AND x.UniqueID <> y.UniqueID
WHERE y.PropertyAddress IS NULL

UPDATE y
SET PropertyAddress = ISNULL(y.PropertyAddress, x.PropertyAddress)
FROM Nashville x
JOIN Nashville y
    ON x.ParcelID = y.ParcelID
    AND x.UniqueID <> y.UniqueID

-- Next, we want to separate the Address into Individual Columns

SELECT PropertyAddress, SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) Address_Sep, SUBSTRING(PropertyAddress, CHARINDEX(', ', PropertyAddress) + 2,LEN(PropertyAddress) - CHARINDEX(', ', PropertyAddress)) City
FROM Nashville

-- The substring did not work, so we check for the inconsistencies within the PropertyAddress column

SELECT COUNT(PropertyAddress)
FROM Nashville
WHERE PropertyAddress NOT LIKE '%,%'

DELETE FROM Nashville
WHERE PropertyAddress NOT LIKE '%,%' 

-- Now we add those columns to the table
ALTER TABLE Nashville
ADD PropertySplitAddress NVARCHAR (255)

ALTER TABLE Nashville
ADD PropertyCity NVARCHAR (255)

UPDATE Nashville
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)

UPDATE Nashville
SET PropertyCity = SUBSTRING(PropertyAddress, CHARINDEX(', ', PropertyAddress) + 2,LEN(PropertyAddress) - CHARINDEX(', ', PropertyAddress)) 

-- Do the same for OwnerAddress

SELECT OwnerAddress, SUBSTRING(OwnerAddress, 1, CHARINDEX(',', OwnerAddress) - 1) Address_Sep, SUBSTRING(OwnerAddress, CHARINDEX(', ', OwnerAddress) + 2,LEN(OwnerAddress) - CHARINDEX(', ', OwnerAddress)) City
FROM Nashville

SELECT COUNT(*)
FROM Nashville
WHERE OwnerAddress IS NULL

-- Many of the rows in OwnerAddress are not populated, so we check for whether the addresses in the PropertyAddress and OwnerAddress are the same so we can populate the OwnerAddress

SELECT CASE WHEN PropertyAddress = OwnerAddressWithoutState THEN '1' ELSE '0' END
FROM 
(SELECT PropertyAddress, SUBSTRING(OwnerAddress, 1, CHARINDEX(',', OwnerAddress, CHARINDEX(',', OwnerAddress) + 1) - 1) OwnerAddressWithoutState 
FROM master.dbo.Nashville 
WHERE OwnerAddress IS NOT NULL) AS xyz

-- The difference comes only from the difference in number of spaces between columns in some rows, so we want to make them all look proper


UPDATE Nashville
SET PropertyAddress = REPLACE(PropertyAddress, '  ', ' '),
OwnerAddress = REPLACE(OwnerAddress, '  ', ' ')

-- Now we can run the comparison again

SELECT sum(case when X = 1 then 1 else 0 end) as priority1
FROM 
(SELECT CASE WHEN PropertyAddress = OwnerAddressWithoutState THEN '1' ELSE '0' END AS X 
FROM 
(SELECT PropertyAddress, SUBSTRING(OwnerAddress, 1, CHARINDEX(',', OwnerAddress, CHARINDEX(',', OwnerAddress) + 1) - 1) OwnerAddressWithoutState 
FROM master.dbo.Nashville 
WHERE OwnerAddress IS NOT NULL) AS xyz) AS zyx

SELECT COUNT(*)
FROM Nashville
WHERE OwnerAddress IS NOT NULL

SELECT PropertyAddress, OwnerAddressWithoutState
FROM (SELECT PropertyAddress, SUBSTRING(OwnerAddress, 1, CHARINDEX(',', OwnerAddress, CHARINDEX(',', OwnerAddress) + 1) - 1) OwnerAddressWithoutState FROM Nashville) AS yyy
WHERE PropertyAddress != OwnerAddressWithoutState

-- So only a small fraction of addresses is different, so we can populatee the OwnerAddress
UPDATE Nashville
SET OwnerAddress = PropertyAddress
WHERE OwnerAddress IS NULL

SELECT * 
FROM Nashville
WHERE OwnerAddress IS NULL

-- Now we can separate OwnerAddress

SELECT OwnerAddress, 
  SUBSTRING(OwnerAddress, 1, CHARINDEX(',', OwnerAddress) - 1) Address_Sep, 
  CASE 
    WHEN LEN(OwnerAddress) - LEN(REPLACE(OwnerAddress, ',', '')) = 2 
    THEN SUBSTRING(OwnerAddress, CHARINDEX(', ', OwnerAddress) + 2, LEN(OwnerAddress) - CHARINDEX(', ', OwnerAddress) - 5) 
    ELSE SUBSTRING(OwnerAddress, CHARINDEX(', ', OwnerAddress) + 2, LEN(OwnerAddress) - CHARINDEX(', ', OwnerAddress) - 1)
  END AS City, 
  CASE
    WHEN LEN(OwnerAddress) - LEN(REPLACE(OwnerAddress, ',', '')) = 2
    THEN RIGHT(OwnerAddress, 2)
    ELSE NULL
  END AS State
FROM Nashville

-- Or the same can be done with PARSENAME function
SELECT 
    OwnerAddress,
    PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 3) Address_Sep,
    PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 2) City,
    PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 1) State
FROM Nashville

ALTER TABLE Nashville
ADD OwnerSplitAddress NVARCHAR (255),
OwnerCity NVARCHAR (255),
OwnerState NVARCHAR (255)

UPDATE Nashville
SET OwnerSplitAddress = CASE 
    WHEN LEN(OwnerAddress) - LEN(REPLACE(OwnerAddress, ',', '')) = 2
    THEN PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 3) 
    ELSE PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 2) 
    END 

UPDATE Nashville
SET OwnerCity = CASE 
    WHEN LEN(OwnerAddress) - LEN(REPLACE(OwnerAddress, ',', '')) = 2
    THEN PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 2) 
    ELSE PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 1) 
    END 

UPDATE Nashville
SET OwnerState = CASE 
    WHEN LEN(OwnerAddress) - LEN(REPLACE(OwnerAddress, ',', '')) = 2
    THEN PARSENAME(REPLACE(OwnerAddress, ', ', '.'), 1) 
    ELSE NULL 
    END 


-- Turn the SoldAsVCacant column into consistent format (N and Y to Yes and No)

SELECT DISTINCT(SoldAsVacant)
FROM Nashville

SELECT DISTINCT(NewSold)
FROM (SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'N' THEN 'No'
WHEN SoldAsVacant = 'Y' THEN 'Yes'
ELSE SoldAsVacant
END NewSold
FROM Nashville) AS NS

UPDATE Nashville
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'N' THEN 'No'
WHEN SoldAsVacant = 'Y' THEN 'Yes'
ELSE SoldAsVacant
END

-- Remove Duplicates
SELECT COUNT(DISTINCT UniqueID)
FROM Nashville

SELECT *
FROM(SELECT LegalReference, COUNT (LegalReference) OVER (PARTITION BY LegalReference) AS Occurence#
FROM Nashville) AS xxx
WHERE Occurence# > 1

SELECT * 
FROM Nashville
WHERE LegalReference = '20130422-0039751'

-- But then check the duplicates for the whole table and delete them

WITH RowNumCTE AS(
SELECT *, 
    ROW_NUMBER() OVER (PARTITION BY ParcelID,
                                    LegalReference,
                                    SalePrice1,
                                    SaleDate1,
                                    PropertyAddress
                                    ORDER BY UniqueID) row_num
FROM Nashville)
DELETE 
FROM RowNumCTE
WHERE row_num > 1


-- As the last step, delete unused columns

ALTER TABLE Nashville
DROP COLUMN OwnerAddress, PropertyAddress, SalePrice, TaxDistrict












    

















