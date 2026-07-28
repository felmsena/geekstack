module Spree::Api::V3::Store::CustomersControllerDecorator
  private

  def permitted_params
    parameters = super
    parameters[:rut] = params[:rut] if params.key?(:rut)
    parameters
  end
end

Spree::Api::V3::Store::CustomersController.prepend(Spree::Api::V3::Store::CustomersControllerDecorator)
