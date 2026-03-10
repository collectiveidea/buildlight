FactoryBot.define do
  factory :device do
    usernames { [] }
    projects { [] }
    sequence(:name) { |i| "Device #{i}" }
    sequence(:slug) { |i| "slug-#{i}" }

    trait :with_identifier do
      sequence(:identifier) { |i| "device-#{i}" }
    end

    # Set webhook_url via update_column to avoid triggering callbacks
    transient do
      webhook_url { nil }
    end

    after(:create) do |device, evaluator|
      if evaluator.webhook_url
        device.update_column(:webhook_url, evaluator.webhook_url)
      end
    end
  end

  factory :status do
    service { "travis" }
    sequence(:project_id, &:to_s)
    sequence(:project_name) { |i| "buildlight#{i}" }
    red { false }
    yellow { false }
  end
end
