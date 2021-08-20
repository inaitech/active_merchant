require 'test_helper'

class RemoteRazorpayTest < Test::Unit::TestCase
  def setup
    @gateway = RazorpayGateway.new(fixtures(:razorpay))

    @amount = 5000
    @credit_card = 'pay_HnTllcQFCxVGNu'
    @declined_card = 'pay_HnTllcQFCxVGNU'
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      currency: 'INR',
      phone: '917912341123',
      email: 'user@example.com'
    }
  end

  def test_successful_purchase
    # TODO: Add payment initiation call before purchase call.
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_failed_purchase
    # TODO: Add payment initiation call and capture it before purchase call.
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Only payments which have been authorized and not yet captured can be captured', response.message
  end

  def test_successful_authorize_and_capture
    # Add initiate call before the capture call
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The id provided does not exist', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_failure capture
    assert_equal 'Capture amount must be equal to the amount authorized', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Payment ID is mandatory', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'OK', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'test')
    assert_failure response
    assert_equal 'The id provided does not exist', response.message
  end

  def test_successful_void
    assert void = @gateway.void(@credit_card, @options)
    assert_success void
    assert_equal 'Razorpay does not support void api', void.message
  end

  def test_invalid_login
    gateway = RazorpayGateway.new(key_id: '', key_secret: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "The api key provided is invalid", response.message
  end

end