require 'active_record'

module DcidevActiveRecord
  ActiveRecord.class_eval do

    scope :between_date, -> (column, start_date, end_date) { where("#{self.date_builder("#{self.table_name}.#{column}")} BETWEEN ? AND ?", start_date, end_date) }
    scope :before_or_equal_to_date, -> (column, date) { where("#{self.date_builder("#{self.table_name}.#{column}")} <= ?", date) }
    scope :after_or_equal_to_date, -> (column, date) { where("#{self.date_builder("#{self.table_name}.#{column}")} >= ?", date) }
    scope :at_time, -> (column, time) { where("#{self.time_builder("#{self.table_name}.#{column}")} LIKE ?", "%#{time}%") }
    scope :mysql_json_contains,(column, value) -> {"JSON_EXTRACT(#{column}, '$.\"Request-ID\"') LIKE \"%#{value}%\""}


    def update_by_params(params, set_nil = true)
        ActiveRecord::Base.transaction do
          self.class.column_names.each do |c|
            begin
              if set_nil
                eval("self.#{c} = params[:#{c.to_sym}]") if params.key?(c.to_sym)
                eval("self.#{c} = params['#{c}']") if params.key?(c)
              else
                eval("self.#{c} = params[:#{c.to_sym}]") if params.key?(c.to_sym) && params[c.to_sym] != nil
                eval("self.#{c} = params['#{c}']") if params.key?(c) && params[c] != nil
              end
            rescue IOError
              raise "Tidak dapat menyimpan file#{c}"
            end
          end
          params.select{|k, _| !k.is_a?(Symbol) && k.include?("_attributes")}.each do |k, _|
            eval("self.#{k} = params[:#{k.to_sym}]")
          end
          self.save
        end
      end

      def mysql_date_builder(field)
        "DATE(CONVERT_TZ(#{field}, '+00:00', '#{Time.now.in_time_zone(Time.zone.name.to_s).formatted_offset}'))"
      end
    
      def mysql_time_builder(field)
        "TIME(CONVERT_TZ(#{field}, '+00:00', '#{Time.now.in_time_zone(Time.zone.name.to_s).formatted_offset}'))"
      end

      def postgresql_date_builder(field)
        "DATE(#{field}::TIMESTAMPTZ AT TIME ZONE '#{Time.zone.now.formatted_offset}'::INTERVAL)"
      end
  
      def postgresql_time_builder(field)
        "#{field}::TIMESTAMPTZ AT TIME ZONE '#{Time.zone.now.formatted_offset}'"
      end

      def set_order
        return unless self.class.column_names.include?("view_order")
        if self.view_order.present?
          self.reorder
        else
          self.view_order = self.class.where.not(id: self.id).count + 1
          self.save
        end
      end

      def reorder
        return unless self.class.column_names.include?("view_order")
        return unless self.class.where(view_order: self.view_order).where.not(id: self.id).present?
        self.class.order(view_order: :asc, updated_at: :desc).each.with_index(1) do |f, i|
          f.update(view_order: i)
        end
      end
  end
end