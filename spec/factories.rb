FactoryGirl.define do
  factory :status do
    sequence(:project_id)   {|i| i.to_s }
    sequence(:project_name) {|i| "buildlight#{i}" }
    red false
    yellow false
  end
end