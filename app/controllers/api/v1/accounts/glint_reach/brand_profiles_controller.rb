class Api::V1::Accounts::GlintReach::BrandProfilesController < Api::V1::Accounts::GlintReach::BaseController
  def show
    @brand_profile = Current.account.glint_reach_brand_profile
  end

  # PUT creates the account's profile on first save and updates it afterwards.
  def update
    @brand_profile = Current.account.glint_reach_brand_profile || Current.account.build_glint_reach_brand_profile
    @brand_profile.update!(brand_profile_params)
    render :show
  end

  private

  def brand_profile_params
    params.require(:brand_profile).permit(
      :name, :description, :website_url, :products_services, :target_audience, :geographic_market,
      :voice_and_tone, :messaging_guidelines, :prohibited_claims,
      preferred_languages: [], approved_ctas: []
    )
  end
end
