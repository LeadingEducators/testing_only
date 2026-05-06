-- ============================================================
-- SAMPLE SQL QUERY
-- Purpose: Demonstrate CTEs, JOINs, aggregations, and filters
-- Context: Fictional school district with students, courses,
--          enrollments, and teachers
-- ============================================================


-- ============================================================
-- BASE TABLES (for reference)
-- ============================================================
--
-- students        (student_id, first_name, last_name, grade_level, enrollment_date)
-- teachers        (teacher_id, first_name, last_name, department)
-- courses         (course_id, course_name, teacher_id, max_capacity)
-- enrollments     (enrollment_id, student_id, course_id, grade, status)
--
-- ============================================================


WITH

-- ------------------------------------------------------------
-- CTE 1: Active enrollments only
-- Filters out dropped or withdrawn students
-- ------------------------------------------------------------
active_enrollments AS (
    SELECT
        enrollment_id,
        student_id,
        course_id,
        grade
    FROM enrollments
    WHERE status = 'active'
),


-- ------------------------------------------------------------
-- CTE 2: Course summary
-- Counts enrolled students and calculates average grade per course
-- ------------------------------------------------------------
course_summary AS (
    SELECT
        course_id,
        COUNT(student_id)   AS enrolled_count,
        AVG(grade)          AS avg_grade
    FROM active_enrollments
    GROUP BY course_id
),


-- ------------------------------------------------------------
-- CTE 3: High demand courses
-- Flags courses that are at or above 80% capacity
-- ------------------------------------------------------------
high_demand_courses AS (
    SELECT
        c.course_id,
        c.course_name,
        c.max_capacity,
        cs.enrolled_count,
        cs.avg_grade,
        ROUND(cs.enrolled_count * 100.0 / c.max_capacity, 1) AS pct_full
    FROM courses c
    INNER JOIN course_summary cs
        ON c.course_id = cs.course_id
    WHERE cs.enrolled_count >= c.max_capacity * 0.8
)


-- ------------------------------------------------------------
-- FINAL SELECT
-- Pulls together students, their courses, teacher info,
-- and flags which courses are high demand
-- ------------------------------------------------------------
SELECT
    -- Student info
    s.student_id,
    s.first_name                            AS student_first,
    s.last_name                             AS student_last,
    s.grade_level,

    -- Course info
    hdc.course_name,
    hdc.pct_full,
    hdc.avg_grade                           AS course_avg_grade,

    -- Teacher info
    t.first_name || ' ' || t.last_name      AS teacher_name,
    t.department,

    -- Student's individual grade in this course
    ae.grade                                AS student_grade,

    -- Flag students performing below the course average
    CASE
        WHEN ae.grade < hdc.avg_grade THEN 'Below Average'
        WHEN ae.grade = hdc.avg_grade THEN 'At Average'
        ELSE 'Above Average'
    END                                     AS performance_flag

FROM students s

    -- Only include students with active enrollments
    INNER JOIN active_enrollments ae
        ON s.student_id = ae.student_id

    -- Only show high demand courses
    INNER JOIN high_demand_courses hdc
        ON ae.course_id = hdc.course_id

    -- Bring in teacher details (LEFT JOIN in case teacher is unassigned)
    LEFT JOIN teachers t
        ON hdc.course_id = (
            SELECT course_id
            FROM courses
            WHERE teacher_id = t.teacher_id
            LIMIT 1
        )

ORDER BY
    hdc.pct_full    DESC,   -- Most full courses first
    s.grade_level   ASC,    -- Then by grade level
    s.last_name     ASC     -- Then alphabetically
;