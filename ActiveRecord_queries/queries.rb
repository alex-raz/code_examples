# models:
# Ahoy::Event(id: uuid, visit_id: uuid, name: string, time: datetime, properties: jsonb)
# Product(id: integer, name: string, description: text)
#
# task:
# implement a scope to display most viewed products
scope :ordered_by_most_viewed_in, (lambda do |time|
  joins("
    INNER JOIN (
      #{Ahoy::Event.where(time: time).to_sql}
    ) AS ahoy_events_by_time
    ON (ahoy_events_by_time.properties->>'id')::Integer = products.id
  ")
  .select('products.*, COUNT(ahoy_events_by_time.id) AS views_count')
  .group('products.id')
  .order('views_count DESC')
end)

# models:
# Earning(id: integer, user_id: integer, user_income: decimal, status: string, paid_date: date, created_at: datetime)
# User(id: integer)
#
# task:
# implement a class method to display users with their total unpaid incomes for given date
def self.payment_earnings(payment_date:, amount: 50, status: 'pending')
  Earning
    .where(status: status, paid_date: nil)
    .where('earnings.created_at < ?', payment_date)
    .joins(:user)
    .select('users.id as user_id, sum(earnings.user_income) as total_income')
    .group('users.id')
    .having('sum(earnings.user_income) > ?', amount)
end
