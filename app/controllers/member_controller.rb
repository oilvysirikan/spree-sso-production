class MemberController < ApplicationController
  layout 'member'

  def show
    line_user_id = params[:line_user_id] || session[:line_user_id]
    return redirect_to member_login_path unless line_user_id

    social = SocialAccount.includes(:spree_user).find_by(provider: 'line', uid: line_user_id)
    return render 'not_linked' unless social

    @user = social.spree_user
    @points = @user.public_metadata&.dig('shopify_points') || 0
    @total_spent = @user.public_metadata&.dig('shopify_total_spent') || 0
    @line_name = social.line_display_name
    @line_picture = social.line_picture_url

    shopify = ShopifySyncService.new.sync_customer_orders(email: @user.email)
    @orders = shopify[:orders] || []
    @total_orders = shopify[:total_orders] || 0
  end

  def login
    # LINE LIFF will handle login and redirect with line_user_id
  end
end
