module ApplicationHelper
  TIERS = [
    { name: 'Bronze', icon: '🥉', min: 0,    max: 499   },
    { name: 'Silver', icon: '🥈', min: 500,  max: 1499  },
    { name: 'Gold',   icon: '🥇', min: 1500, max: 3999  },
    { name: 'Platinum', icon: '💎', min: 4000, max: nil }
  ].freeze

  def calc_tier(points)
    current = TIERS.reverse.find { |t| points >= t[:min] } || TIERS.first
    next_tier = TIERS.find { |t| t[:min] > current[:min] }
    pts_needed = next_tier ? next_tier[:min] - points : 0
    [current[:name], next_tier&.dig(:name), pts_needed, current[:icon]]
  end

  def tier_progress(points)
    current = TIERS.reverse.find { |t| points >= t[:min] } || TIERS.first
    next_t = TIERS.find { |t| t[:min] > current[:min] }
    return 100 unless next_t

    range = next_t[:min] - current[:min]
    earned = points - current[:min]
    [(earned.to_f / range * 100).round, 100].min
  end
end
