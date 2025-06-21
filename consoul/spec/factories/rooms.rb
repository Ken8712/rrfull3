FactoryBot.define do
  factory :room do
    title { "MyString" }
    status { "MyString" }
    user1 { nil }
    user2 { nil }
    timer_seconds { 1 }
    timer_running { false }
    timer_started_at { "2025-06-20 16:56:35" }
    heart_count { 1 }
    started_at { "2025-06-20 16:56:35" }
    ended_at { "2025-06-20 16:56:35" }
    last_activity_at { "2025-06-20 16:56:35" }
  end
end
