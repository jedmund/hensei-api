# frozen_string_literal: true

RSpec.shared_examples 'a model with unique order' do |factory|
  let!(:first) { create(factory, order: 1) }
  let!(:second) { create(factory, order: 2) }
  let!(:third) { create(factory, order: 3) }
  let!(:fourth) { create(factory, order: 4) }
  let(:records) { [first, second, third, fourth] }

  def orders
    records.map { |record| record.reload.order }
  end

  it 'shifts the records in between when moved earlier' do
    fourth.update!(order: 2)
    expect(orders).to eq([1, 3, 4, 2])
  end

  it 'shifts the records in between when moved later' do
    first.update!(order: 3)
    expect(orders).to eq([3, 1, 2, 4])
  end

  it 'leaves other records alone when the order is unchanged' do
    expect { second.update!(name_en: 'Renamed') }.not_to(change { orders })
  end

  it 'leaves other records alone when the update is invalid' do
    expect(fourth.update(order: 2, name_en: '')).to be(false)
    expect(orders).to eq([1, 2, 3, 4])
  end

  it 'marks shifted records as updated' do
    expect { fourth.update!(order: 3) }.to(change { third.reload.updated_at })
  end

  it 'makes room when a new record takes an order in use' do
    added = create(factory, order: 2)
    expect(orders).to eq([1, 3, 4, 5])
    expect(added.reload.order).to eq(2)
  end

  it 'leaves other records alone when a new record takes a free order' do
    create(factory, order: 5)
    expect(orders).to eq([1, 2, 3, 4])
  end
end
