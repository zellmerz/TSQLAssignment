--1. Create a stored procedure named spInsertDepartment that takes as a parameter a value for the department name and adds a new row into the Departments table. 

--	 Even though Departments table allows null department name, validate that department name is provided and is not an empty string. 
--	 Throw an error with message “Department name must be provided” if incorrect.

--	Department name has to be unique. The procedure should throw an error with message “Department name must be unique” upon attempt to insert a department with 
--	a name that is already in the table.

--Code three tests executing this procedure: 1) with null or empty department name, 2) with a unique department name, and 3) with a duplicate department name. 

USE College;
GO

IF OBJECT_ID ('spInsertDepartment') IS NOT NULL
	DROP PROC spInsertVendor;

GO

IF OBJECT_ID ('fnStudentUnits') IS NOT NULL
	DROP PROC fnStudentUnits;

GO

IF OBJECT_ID ('fnTuition') IS NOT NULL
	DROP PROC fnTuition;

GO


CREATE OR ALTER PROC spInsertDepartment
	@DepartmentName VARCHAR(40) = NULL
AS
-- verify departmentname is present
IF @DepartmentName IS NULL
	THROW 50001, 'Department Name must be provided.', 0

-- validate DepartmentName is unique
IF @DepartmentName = (SELECT DepartmentName FROM Departments
					 WHERE DepartmentName = @DepartmentName)
	THROW 50002, 'Department Name must be unique.', 1

--Validation passed so insert data
INSERT Departments
VALUES (@DepartmentName)
GO

EXEC spInsertDepartment
	@DepartmentName = NULL

EXEC spInsertDepartment
	@DepartmentName = 'Computer Science'


SELECT * FROM DEPARTMENTS ORDER BY DepartmentID

GO


--2.Create a function named fnStudentUnits that calculates the sum of course units of a student. 
--	This function accepts one parameter, the student ID, and returns an integer value that is the sum of the course units for the student. 
--	You can find courses that the student takes in StudentCourses table, and CourseUnits for each course in the Courses tables. 
--	If the student does not exist or has no courses, this function should return 0.

--	Code three tests: 1) for a student who has courses, 2) for student who does not have courses, and 3) a non-existing student ID. 
--	For each test, display the value of the student ID that was passed to the function and the result returned by the function. 
--	Also, run a supportive SELECT query or queries that prove the test results are correct.


-- will need to grab CourseIDs from tbl.StudentCourses
-- then use those courseIDs to generate CourseUnits from tbl.Courses
-- then SUM CourseUnits

CREATE OR ALTER FUNCTION fnStudentUnits (@StudentID INT)
	RETURNS INT
BEGIN
	-- create results variable for easy if/else
	DECLARE @Result INT;
	-- if student doesn't exist
	IF (NOT EXISTS (SELECT StudentID FROM Students
				    WHERE StudentID = @StudentID))
		SELECT @Result = 0;	
	-- or if student hasn't taken any courses
	ELSE IF (NOT EXISTS (SELECT CourseID FROM StudentCourses
						 JOIN Students ON StudentCourses.StudentID = Students.StudentID
						 WHERE Students.StudentID = @StudentID))
		-- return 0
		SELECT @Result = 0;
	-- student exists and has courses
	ELSE
		SELECT @Result = SUM(CourseUnits)
		FROM StudentCourses JOIN Courses ON StudentCourses.CourseID = Courses.CourseID
		WHERE StudentID = @StudentID
		GROUP BY StudentCourses.StudentID

	RETURN @Result		  
END
GO

DECLARE @UnitsCount INT = dbo.fnStudentUnits(5);
PRINT 'Total Course units = ' + Convert(VARCHAR, @UnitsCount)
GO

DECLARE @UnitsCount INT = dbo.fnStudentUnits(1);
PRINT 'Total Course units = ' + Convert(VARCHAR, @UnitsCount)
GO

DECLARE @UnitsCount INT = dbo.fnStudentUnits(50);
PRINT 'Total Course units = ' + Convert(VARCHAR, @UnitsCount)

SELECT * FROM Students
SELECT * FROM StudentCourses
SELECT * FROM Courses

GO



--3.Create a function named fnTuition that calculates the tuition for a student. 
	--This function accepts one parameter, the student ID, and it calls the fnStudentUnits function that you created in task 2. 
	--The tuition value for the student calculated according to the following pseudocode:
	--if (student does not exist) or (student units = 0)
	--   tuition = 0
	--else if (student units >= 9)
	--   tuition = (full time cost) + (student units) * (per unit cost)
	--else 
	--   tuition = (part time cost) + (student units) * (per unit cost)

	--Retrieve values of FullTimeCost, PartTimeCost, and PerUnitCost from table Tuition.

	--If there is no student with the ID passed to the function, the function should return -1.

	--Code two tests: 1) a student who has < 9 student units, and 2) for a student who has >= 9 student units. 
	--For each test, display StudentID and the result returned by the function. Also, run supportive SELECT query or queries that prove the results to be correct.


	--PartTimeCost = 750, FullTimeCost = 1250, PerUnitCost= 62.50

CREATE OR ALTER FUNCTION fnTuition (@StudentID INT)
	RETURNS MONEY
BEGIN
	-- declare variables
	DECLARE @Result MONEY;
	DECLARE @FullTimeCost MONEY;
	DECLARE @PartTimeCost MONEY;
	DECLARE @PerUnitCost MONEY;
	-- set required variables
	SET @FullTimeCost = (SELECT FullTimeCost FROM Tuition)
	SET @PartTimeCost = (SELECT PartTimeCost FROM Tuition)
	SET @PerUnitCost = (SELECT PerUnitCost FROM Tuition)
	-- if student ID doesn't exist, or does not have courses fnStudentUnits will return 0
	-- therefore if 0 is returned, student doesnt exist, or has no courses, set result to 0
	IF (dbo.fnStudentUnits(@StudentID) = 0)
		SELECT @Result = 0;
	-- student exists and has enough course units for fulltime status
	ELSE IF (dbo.fnStudentUnits(@StudentID) >= 9)
		SELECT @Result = (@FullTimeCost + dbo.fnStudentUnits(@StudentID) * @PerUnitCost)
	-- student exists, has courses, but not enough for full time status
	ELSE
		SELECT @Result = (@PartTimeCost + dbo.fnStudentUnits(@StudentID) * @PerUnitCost)
	RETURN @Result
END
GO

DECLARE @TuitionCost MONEY = dbo.fnTuition(5);
PRINT 'Total Tuition costs = ' + FORMAT(@TuitionCost, 'c')
GO

DECLARE @TuitionCost MONEY = dbo.fnTuition(10);
PRINT 'Total Tuition costs = ' + FORMAT(@TuitionCost, 'c')
GO

SELECT (1250 + dbo.fnStudentUnits(5) * 62.5)
SELECT (750 + dbo.fnStudentUnits(10) * 62.5)

SELECT * FROM Tuition
SELECT * FROM Courses
SELECT * FROM StudentCourses

GO


--4.Create a trigger named InstructorInsertSalaryTR that fires when a new row is added to the Instructors table.
	--Throw an error when multiple rows are inserted.
	--When there is only one row inserted, validate that the AnnualSalary value is positive (strictly greater than zero) and less than or equal to 120000. 
	--Throw an error with appropriate message if the salary value is negative or too big. 
	--Also, if the salary value is between 0 and 10000, assume that there was a mistake of entering monthly salary instead of annual salary, and multiply the salary value by 12. 
	--For example, if the new value of the salary is 5000, it should be changed to 60000. 
	--No need to validate any other data from the inserted row.

	--Test the trigger with appropriate INSERT statements. 
	--There should be four cases: 1) with negative salary, 2) with positive salary <= 10000, 3) 
	--with salary greater that 10000 and less than or equal to 120000, and 4) with salary > 120000.


CREATE OR ALTER TRIGGER InstructorInsertSalaryTR
ON Instructors
INSTEAD OF INSERT
AS
	SELECT * FROM inserted
-- declare needed variables
DECLARE @LastName VARCHAR(25),
		@FirstName VARCHAR(25),
		@Status CHAR(1),
		@DepartmentChairman BIT,
		@HireDate DATE,
		@AnnualSalary MONEY,
		@DepartmentID INT

-- ensure only 1 row inserted
DECLARE @Count INT;
SELECT @Count = COUNT(*) FROM Inserted;
IF @Count > 1
	THROW 50000, 'Insert limited to one row at a time', 0;

-- ensure required values are set
SELECT	@LastName = LastName,
		@FirstName = FirstName,
		@Status = Status,
		@DepartmentChairman = DepartmentChairman,
		@HireDate = HireDate,
		@AnnualSalary = AnnualSalary,
		@DepartmentID = DepartmentID
FROM inserted;
-- validate salary range
IF @AnnualSalary < 0
	THROW 50001, 'Salary must be greater than 0', 0;
IF @AnnualSalary >= 120000
	THROW 50001, 'Salary cannot be greater or equal to 120000', 0;
IF @AnnualSalary > 0 AND @AnnualSalary < 10000
	SET @AnnualSalary = @AnnualSalary * 12;
-- insert all data
INSERT INTO Instructors(LastName, FirstName, Status, DepartmentChairman, HireDate, AnnualSalary, DepartmentID)
VALUES (@LastName, @FirstName, @Status, @DepartmentChairman, @HireDate, @AnnualSalary, @DepartmentID)

--Test the trigger with appropriate INSERT statements. 
	--There should be four cases: 1) with negative salary, 2) with positive salary <= 10000, 3) 
	--with salary greater that 10000 and less than or equal to 120000, and 4) with salary > 120000.

SELECT * FROM Instructors
-- negative salary
INSERT INTO Instructors
VALUES ('Doe', 'John', 'F', 1, GetDate(), -100, 1)
-- positive salary <= 10000
INSERT INTO Instructors
VALUES ('Doe', 'John', 'F', 1, GetDate(), 5000, 1)
-- salary > 10000 and <120000
INSERT INTO Instructors
VALUES ('Anderson', 'Thomas', 'F', 1, GetDate(), 100000, 1)
-- salary >= 120000
INSERT INTO Instructors
VALUES ('Anderson', 'Thomas', 'F', 1, GetDate(), 200000, 1)
-- additional test
INSERT INTO Instructors
VALUES ('Smith', 'Sally', 'F', 1, GetDate(), 115000, 1)

GO


--5.Write a script that produces the following report: 
--	For each instructor, display one line with InstructorID, last name, first name, how many courses the instructor teaches, and a note that is defined as follows:
--	•	“On leave”, when instructor teaches no courses, 
--	•	“Available for another course”, when instructor teaches only one course, and
--	•	Nothing otherwise
--	Instructors table contains data about instructors, and each course in the Courses table references InstructorID of an instructor who teaches the course.
--	The structure of the script is totally up to you, as long as it displays the desired report.


	-- something I was starting with, but realized it either wouldn't work, or would just make things more complex than needed
--CREATE OR ALTER FUNCTION fnInstructorStatus(@InstructorID INT)
--	RETURNS VARCHAR
--BEGIN
--	DECLARE @RESULT VARCHAR;
--	IF (NOT EXISTS(SELECT InstructorID FROM Courses
--				   WHERE InstructorID = @InstructorID))
--		SELECT @Result = 'On leave';
--	ELSE IF (SELECT COUNT(InstructorID) FROM Courses
--			 WHERE InstructorID = @InstructorID) = 1
--		SELECT @Result = 'Available for another course';
--	ELSE
--		SELECT @Result = NULL;
--	RETURN @Result
--END

--GO

-- create function to easily get total course count for an instructor
CREATE OR ALTER FUNCTION fnInstructorCourseCount(@InstructorID INT)
	RETURNS INT
BEGIN
	DECLARE @Result INT;
		SELECT @Result = COUNT(InstructorID) FROM Courses WHERE InstructorID = @InstructorID
	RETURN @Result
END

GO


SELECT Instructors.InstructorID, LastName, FirstName, dbo.fnInstructorCourseCount(Instructors.InstructorID) AS [# of Courses],
	   -- determine number of courses Instructor is teaching and change note accordingly
	   CASE WHEN (dbo.fnInstructorCourseCount(Instructors.InstructorID) = 0) -- no courses
				THEN 'On leave'
			WHEN (dbo.fnInstructorCourseCount(Instructors.InstructorID) = 1) -- 1 course
				THEN 'Available for another course'
			ELSE															 -- 2 or more courses
				'' END AS Note
FROM Instructors LEFT JOIN Courses ON Instructors.InstructorID = Courses.InstructorID
GROUP BY Instructors.InstructorID, LastName, FirstName


CREATE OR ALTER VIEW InstructorInfo
AS	   
SELECT Instructors.InstructorID, LastName, FirstName, dbo.fnInstructorCourseCount(Instructors.InstructorID) AS [# of Courses]
FROM Instructors JOIN Courses ON Instructors.InstructorID = Courses.InstructorID

GO	   

SELECT * FROM InstructorInfo
 
GO

