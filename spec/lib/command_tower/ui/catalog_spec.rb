# frozen_string_literal: true

RSpec.describe CommandTower::UI::Catalog, :aggregate_failures do
  it "exposes the constants" do
    expect(CommandTower::UI::CATALOG).to eq(2)
    expect(CommandTower::UI::SCHEMA).to eq("ui_document")
  end

  it "nests the errors under CommandTower::Error" do
    %i[InvalidDocumentError InvalidTokenError InvalidFragmentError].each do |name|
      expect(CommandTower::UI.const_get(name).superclass).to eq(CommandTower::Error)
    end
  end

  describe ".from_header" do
    {
      "1" => 1,
      "2" => 2,
      " 2 " => 2,
      2 => 2,
      "3" => 2,
      "99" => 2,
      nil => 1,
      "" => 1,
      "  " => 1,
      "0" => 1,
      "-1" => 1,
      "abc" => 1,
      "1.5" => 1,
      "2abc" => 1
    }.each do |input, expected|
      it "maps #{input.inspect} to #{expected}" do
        expect(described_class.from_header(input)).to eq(expected)
      end
    end
  end
end
