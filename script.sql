-- ==========================================
-- 1. Setup & Extensions
-- ==========================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS vector; -- ต้องติดตั้ง pgvector ที่เครื่อง Server ก่อนนะครับ

-- ฟังก์ชันสำหรับอัปเดต updated_at อัตโนมัติ
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ==========================================
-- 2. Users & Profiles Domain
-- ==========================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('student', 'company', 'admin')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE student_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    university VARCHAR(200),
    graduation_year INTEGER,
    bio TEXT,
    resume_url TEXT,
    parsed_resume_text TEXT
);

CREATE TABLE company_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(200) NOT NULL,
    industry VARCHAR(100),
    description TEXT,
    logo_url TEXT,
    website TEXT
);

-- ==========================================
-- 3. Skill & Assessment Domain
-- ==========================================
CREATE TABLE skills (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('hard_skill', 'soft_skill', 'trait')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE student_skills (
    student_id UUID REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    skill_id INTEGER REFERENCES skills(id) ON DELETE CASCADE,
    proficiency_level INTEGER CHECK (proficiency_level BETWEEN 1 AND 10),
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (student_id, skill_id)
);

CREATE TABLE assessments (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE assessment_questions (
    id SERIAL PRIMARY KEY,
    assessment_id INTEGER REFERENCES assessments(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL, 
    correct_answer_key VARCHAR(50),
    order_index INTEGER DEFAULT 0
);

CREATE TABLE assessment_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    assessment_id INTEGER REFERENCES assessments(id) ON DELETE SET NULL,
    total_score INTEGER DEFAULT 0,
    details JSONB, 
    submitted_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 4. Job & Matching Domain (AI Powered)
-- ==========================================
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES company_profiles(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    salary_range_min INTEGER,
    salary_range_max INTEGER,
    job_type VARCHAR(50) CHECK (job_type IN ('internship', 'full_time', 'project_based', 'contract')), 
    location VARCHAR(100),
    embedding_vector vector(1536), 
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index สำหรับ Vector Search (สำคัญมาก)
CREATE INDEX ON jobs USING hnsw (embedding_vector vector_cosine_ops);
CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE job_skills (
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    skill_id INTEGER REFERENCES skills(id) ON DELETE CASCADE,
    required_level INTEGER CHECK (required_level BETWEEN 1 AND 10),
    PRIMARY KEY (job_id, skill_id)
);

CREATE TABLE job_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    student_id UUID REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    match_score DOUBLE PRECISION, 
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'viewed', 'interview', 'rejected', 'offered')),
    cover_letter TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(job_id, student_id)
);

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON job_applications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================
-- 5. Portfolio & Education
-- ==========================================
CREATE TABLE educations (
    id SERIAL PRIMARY KEY,
    student_id UUID REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    institution_name VARCHAR(200) NOT NULL,
    degree VARCHAR(100),
    field_of_study VARCHAR(100),
    gpa NUMERIC(3, 2) CHECK (gpa >= 0.00 AND gpa <= 4.00), 
    start_date DATE,
    end_date DATE,
    CHECK (end_date IS NULL OR start_date <= end_date)
);

CREATE TABLE portfolios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    project_url TEXT,
    thumbnail_url TEXT,
    embedding_vector vector(1536), 
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON portfolios USING hnsw (embedding_vector vector_cosine_ops);
CREATE TRIGGER update_portfolios_updated_at BEFORE UPDATE ON portfolios FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================
-- 6. Interviews & Audit Logs (Automation Included)
-- ==========================================
CREATE TABLE interviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID REFERENCES job_applications(id) ON DELETE CASCADE,
    interview_date TIMESTAMPTZ NOT NULL,
    location_type VARCHAR(50) CHECK (location_type IN ('online', 'onsite')),
    meeting_link TEXT,
    interviewer_notes TEXT,
    rating INTEGER CHECK (rating BETWEEN 1 AND 10),
    status VARCHAR(50) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'canceled', 'no_show')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_interviews_updated_at BEFORE UPDATE ON interviews FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE application_timelines (
    id SERIAL PRIMARY KEY,
    application_id UUID REFERENCES job_applications(id) ON DELETE CASCADE,
    previous_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL, 
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Automation: Function & Trigger สำหรับบันทึก Log อัตโนมัติ
CREATE OR REPLACE FUNCTION log_application_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO application_timelines (application_id, previous_status, new_status, changed_at)
        VALUES (NEW.id, OLD.status, NEW.status, NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_status_change
AFTER UPDATE ON job_applications
FOR EACH ROW
EXECUTE FUNCTION log_application_status_change();

-- ==========================================
-- 7. Subscriptions & Payments (ส่วนที่ขาดไป)
-- ==========================================
CREATE TABLE subscription_plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    job_post_limit INTEGER NOT NULL DEFAULT 0,
    resume_search_limit INTEGER NOT NULL DEFAULT 0,
    duration_days INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE company_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES company_profiles(user_id) ON DELETE CASCADE,
    plan_id INTEGER REFERENCES subscription_plans(id),
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled', 'pending_payment')),
    used_job_posts INTEGER DEFAULT 0,
    used_resume_searches INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON company_subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_subscription_id UUID REFERENCES company_subscriptions(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'THB',
    payment_method VARCHAR(50) CHECK (payment_method IN ('credit_card', 'bank_transfer', 'promptpay')),
    transaction_id VARCHAR(255),
    gateway_response JSONB, 
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);