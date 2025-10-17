# frozen_string_literal: true

module Newshound
  module Authorization
    class << self
      # Check if the current user/controller is authorized to view Newshound data
      def authorized?(controller)
        return false unless Newshound.configuration.enabled

        # Use custom authorization block if provided
        if Newshound.configuration.authorization_block
          return Newshound.configuration.authorization_block.call(controller)
        end

        # Default authorization: check if current_user has an authorized role
        user = current_user_from(controller)
        return false unless user

        user_role = user_role_from(user)
        return false unless user_role

        Newshound.configuration.authorized_roles.include?(user_role.to_sym)
      end

      private

      def current_user_from(controller)
        method_name = Newshound.configuration.current_user_method
        return nil unless controller.respond_to?(method_name)

        controller.send(method_name)
      end

      def user_role_from(user)
        return nil unless user

        # Try common role attribute names
        [:role, :user_role, :type].each do |attr|
          return user.send(attr) if user.respond_to?(attr)
        end

        nil
      end
    end
  end
end
