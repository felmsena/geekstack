module Spree::Api::V3::Admin::CustomersControllerDecorator
  private

  def permitted_params
    parameters = super
    parameters[:rut] = params[:rut] if params.key?(:rut)
    parameters
  end
end

Spree::Api::V3::Admin::CustomersController.prepend(Spree::Api::V3::Admin::CustomersControllerDecorator)
