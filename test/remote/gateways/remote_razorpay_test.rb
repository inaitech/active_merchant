require 'test_helper'

class RemoteRazorpayTest < Test::Unit::TestCase
  def setup
    @gateway = RazorpayGateway.new(fixtures(:razorpay))

    @amount = 5000
    @payment_id = 'pay_Hxh1s5QYjyJQzc'
    @invalid_payment_id = 'pay_HnTllcQFCxVGNU'
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      currency: 'INR',
      phone: '917912341123',
      email: 'user@example.com'
    }
    @order_options = {
      currency: 'INR',
      order_id: 'order-id'
    }
  end

  def test_successful_capture
    response = @gateway.capture(@amount, @payment_id, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_order
    response = @gateway.create_order(@amount, @order_options)
    assert_success response
    assert_equal 'OK', response.message
    assert_match 'created', response.params['status']
    assert response.params['id'] != nil
    assert_equal @order_options[:order_id], response.params['receipt'] 
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Payment ID is mandatory', response.message
  end

  def test_successful_refund
    refund = @gateway.refund(@amount, @payment_id)
    assert_success refund
    assert_equal 'OK', refund.message
  end

  def test_successful_void
    assert void = @gateway.void(@payment_id, @options)
    assert_success void
    assert_equal 'Razorpay does not support void api', void.message
  end

  def test_invalid_login
    gateway = RazorpayGateway.new(key_id: '', key_secret: '')
    response = gateway.capture(@amount, @payment_id, @options)
    assert_failure response
    assert_match "The api key provided is invalid", response.message
  end

end
