require 'rails_helper'

RSpec.describe CustomOverlayBootAssertion do
  describe '.verify!' do
    it 'does nothing when eager load is disabled' do
      allow(Rails.configuration).to receive(:eager_load).and_return(false)

      expect { described_class.verify! }.not_to raise_error
    end

    it 'passes when eager load is enabled and overlays are prepended' do
      allow(Rails.configuration).to receive(:eager_load).and_return(true)

      expect { described_class.verify! }.not_to raise_error
    end
  end
end
