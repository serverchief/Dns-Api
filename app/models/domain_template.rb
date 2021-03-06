class DomainTemplate < ActiveRecord::Base
    has_many :record_templates, :dependent => :destroy, :inverse_of => :domain_template
    has_one  :soa_record_template, :class_name => 'RecordTemplate', :conditions => { 'type' => 'SOA' }, :inverse_of => :domain_template

    validates_presence_of     :name
    validates_uniqueness_of   :name
    validates_presence_of     :ttl
    validates_numericality_of :ttl
    validates_associated      :soa_record_template

    after_create              :create_soa_record_template

    SOA::SOA_FIELDS.each do |field|
        delegate field.to_sym, (field.to_s + '=').to_sym, :to => :soa_record_template
    end

    # scopes
    scope :with_soa, joins(:record_templates).where('record_templates.type = ?', 'SOA')
    default_scope order('name')
    # scope :user, lambda { |user| user.admin? ? nil : where(:user_id => user.id) }

    def soa_record_template
        super || (self.soa_record_template = RecordTemplate.new('type' => 'SOA').tap{ |soa|
            if self.new_record?
                soa.domain_template = self
            else
                soa.domain_template_id = self.id
            end
        })
    end

    # Build a new domain using +self+ as a template. +domain+ should be valid domain
    # name.
    #
    # This method will throw exceptions as it encounters errors, and will use a
    # transaction to complete/rollback the operation.
    def build(domain_name)
        domain = Domain.new(:name           => domain_name,
                            :ttl            => self.ttl,
                            :authority_type => Domain::MASTER)

        record_templates.dup.each do |template|
            record = template.build(domain_name)

            domain.records   << record
            domain.soa_record = record if record.is_a?(SOA)
        end

        domain
    end

    def create_soa_record_template
        soa_record_template.save or raise "[ERROR] unable to save SOA record template(#{soa_record_template.errors.full_messages})"
    end
end
