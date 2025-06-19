FactoryBot.define do
  factory :session do
    title { "MyString" }
    status { "MyString" }
    started_at { "2025-06-19 22:30:15" }
    ended_at { "2025-06-19 22:30:15" }
    timer_seconds { 1 }
    timer_running { false }
    timer_started_at { "2025-06-19 22:30:15" }
    heart_count { 1 }
    user1 { nil }
    user2 { nil }
  end
end
