object false

node :errors do
    if @exception.respond_to?(:record)
        errors = ValidationErrorsSerializer.new(@exception.record).serialize
    end

    if @exception.respond_to?(:message) && @exception.respond_to?(:code)
        errors = [
            {
                message: @exception.message,
                code: @exception.code
            }
        ]
    end

    errors
end
