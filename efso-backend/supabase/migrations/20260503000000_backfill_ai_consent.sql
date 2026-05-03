-- Onboarding'de AI consent verilen ama DB'ye yazılmayan kullanıcıları düzelt.
-- Tüm mevcut profillerin consent'i true yapılır (hepsi onboarding'i geçmiş).
UPDATE profiles SET ai_consent_given = true WHERE ai_consent_given = false;
