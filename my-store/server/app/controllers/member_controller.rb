class MemberController < ApplicationController
  include LineLoginGate
  layout 'member'
  before_action :require_line_session

  def show
    social = SocialAccount.includes(:spree_customer).find_by(provider: 'line', uid: @line_uid)
    if social.nil?
      return render :not_linked
    end

    @user         = social.spree_customer
    @line_name    = social.line_display_name
    @line_picture = social.line_picture_url
    @points       = @user.public_metadata['shopify_points'].to_i

    orders = Spree::Order.where(user_id: @user.id, state: 'complete')
                         .order(completed_at: :desc)
                         .limit(20)

    @total_orders = orders.count
    @total_spent  = orders.sum(:total)
    @orders = orders.map do |order|
      {
        order_number: order.number,
        created_at:   order.completed_at,
        status:       order_badge_status(order),
        total_price:  order.total,
        line_items:   order.line_items.map { |li| { title: li.name, quantity: li.quantity } }
      }
    end
  end

  def login
    render layout: 'member'
  end

  private

  def require_line_session
    @line_uid = session[:line_user_id]
    redirect_to member_login_path if @line_uid.blank?
  end

  def order_badge_status(order)
    case order.payment_state
    when 'paid', 'credit_owed' then 'paid'
    when 'void', 'failed'      then 'cancelled'
    else 'pending'
    end
  end
end
