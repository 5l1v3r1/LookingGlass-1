# A helper that formats fields for display by display type
module DisplayTypeSwitcher
  # Get all the fields in the document of a certain type, process them, add output together
  def show_by_type(type, doc, dataspec, action="index")
    # Get all the fields matching the particular type
    fields_of_type = dataspec["source_fields"].select{|field, details| details["display_type"] == type }
    type = update_type_for_action(action, type)

    # Render all fields of the type
    return fields_of_type.inject("") do |str, field|
      str += type_switcher(type, doc, field[0], field[1], action).to_s
      raw(str)
    end
  end

  # Handle some show view fields differently than index fields
  def update_type_for_action(action, type)
    nonstandard_show_types = [
        "Category", "Attachment", "Email Attachment", "Date", "DateTime", "Link", "Named Link",
        "Child Document Link", "Related Link", "Source Link", "Alt Attachment View"]
    (action == "show") && !nonstandard_show_types.include?(type) ? (return "Show") : (return type)
  end

  # Check if there is data for a particular type of field
  def is_data_for_type?(type, doc, dataspec)
    fields_of_type = dataspec["source_fields"].select{|field, details| details["display_type"] == type }
    fields_of_type.each do |field|
      field_data = get_text(doc, field[0], field[1])
      return true if field_data != nil && !field_data.empty?
    end
    return false
  end

  # Check if there is data in field or if an empty field should be displayed (due to being writeable)
  def display_field?(type, action, field_data)
    if !field_data.blank?
      return true
    elsif is_editable?(action)
      return true
    else
      return false
    end
  end

  # Set the css class if it should be editable
  def set_editable_class(action)
    is_editable?(action) ? (return "editable ") : (return "")
  end

  # Return if the field should be editable or not
  def is_editable?(action)
    return (action=="show") && (ENV['WRITEABLE'] == "true")
  end

  # Switch between display types
  def type_switcher(type, doc, field, field_details, action)
    # Get data needed to render fields
    field_data = get_text(doc, field, field_details)
    human_readable_name = human_readable_title(field_details)
    icon = icon_name(field_details)
    editclass = set_editable_class(action)
    
    # Switch by field type
    if display_field?(type, action, field_data)
      case type
      when "Title"
        render partial: "docs/fields/title", locals: {
            doc_title: field_data,
            doc: doc,
            editclass: editclass
        }
      when "Picture"
        render partial: "docs/fields/picture", locals: {
            pic_path: field_data,
            editclass: editclass
        }
      when "Short Text", "Description"
        render partial: "docs/fields/short_text", locals: {
            text: field_data,
            editclass: editclass
        }
      when "Shorter Text", "Tiny Text"
        render partial: "docs/fields/tiny_text", locals: {
            icon: icon,
            text: field_data,
            field: field,
            editclass: editclass
        }
      when "Long Text"
        render partial: "docs/fields/long_text", locals: {
            text: field_data,
            editclass: editclass
        }
      when "Date"
        render partial: "docs/fields/date", locals: {
            date: field_data,
            human_readable: human_readable_name,
            editclass: editclass
        }
      when "DateTime", "Number"
        render partial: "docs/fields/datetime_number", locals: {
            date: field_data,
            human_readable: human_readable_name,
            editclass: editclass
        }
      when "Link"
        render partial: "docs/fields/links", locals: {
            links: field_data,
            editclass: editclass
        }
      when "Named Link"
        render partial: "docs/fields/named_links", locals: {
            data: field_data,
            human_readable: human_readable_name,
            field: field,
            editclass: editclass
        }
      when "Child Document Link"
        children = get_child_documents(doc, field)
        label = field_details["associated_doc_label"]
        render partial: "docs/fields/child_documents", locals: {
            data: children,
            human_readable: label,
            field: field,
            editclass: editclass
        }
      when "Related Link"
        render partial: "docs/fields/related_links", locals: {
            data: field_data,
            human_readable: human_readable_name,
            field: field,
            editclass: editclass
        }
      when "Source Link"
        render partial: "docs/fields/source_link", locals: {
            data: field_data,
            human_readable: human_readable_name,
            field: field,
            editclass: editclass
        }
      when "Attachment"
        return show_attachments_by_type(field_data)
      when "Email Attachment"
        return show_email_attachments_by_type(field_data)
      when "Show"
        render partial: "docs/fields/show_text", locals: {
            text: field_data,
            human_readable: human_readable_name,
            field: field,
            editclass: editclass
        }
      when "Category"
        facet_links = facet_links_for_results(doc, field, field_data)
        if action == "index"
          render partial: "docs/fields/tiny_text", locals: {
              icon: icon,
              text: facet_links,
              field: field,
              editclass: editclass
          }
        elsif action == "show"
          render partial: "docs/fields/show_facets", locals: {
              icon: icon,
              text: facet_links,
              field: field,
              human_readable: human_readable_name,
              editclass: editclass
          }
        elsif action == "show-text"
          render partial: "docs/fields/show_text", locals: {
              text: field_data,
              human_readable: human_readable_name,
              field: field,
              editclass: editclass
          }
        end
      end
    else
      return ""
    end
  end

  # Go through files and show
  def show_attachments_by_type(files)
    files = files.is_a?(Array) ? files : [files]

    # Go through all files and output display
    return files.inject("") do |str, file|
      full_path = (ENV['RAILS_RELATIVE_URL_ROOT']+file).gsub("//", "/")
      str += attachment_file_format_switcher(full_path)
      raw(str)
    end
  end

  # Go through files and show
  def show_email_attachments_by_type(files)
    files = files.is_a?(Array) ? files : [files]

    # Go through all files and output display
    count = 0
    return files.inject("") do |str, file|
      count += 1
      attach_name = file.split("/").last.split("_", 2).last
      full_path = (ENV['RAILS_RELATIVE_URL_ROOT']+file).gsub("//", "/")
      str += (render html: raw("<h3>Attachment: "+attach_name+"</h3>"))
      str += attachment_file_format_switcher(full_path)
      str += (render html: raw("<br /><hr>")) if files.length != count
      raw(str)
    end
  end

  # Get the type for a file path
  def get_file_type(file)
    if file.include?("documentcloud")
      return "doc_cloud"
    else
      return File.extname(URI.parse(URI.encode(file.gsub("[", "%5B").gsub("]", "%5D"))).path)
    end
  end

  # Genearate a link to download the file
  def gen_download_link_name(file)
    # Get the human readable title for the document
    dataspec = get_dataspec_for_doc(@doc)
    title_field = dataspec["source_fields"].select{|field, details| details["display_type"] == "Title" }.keys.first
    doc_title = @doc["_source"][title_field]

    # Get the file name and combine them
    file_name = file.split("/").last
    return "#{doc_title} (#{file_name})"
  end

  # Get the alternate path to the PDF version of office docs and similar
  def get_alt_attachment_path
    if data_for_field_type?(@dataspec, @doc, "Alt Attachment View")
      return get_text(@doc, "lg_pdf_view", @dataspec["source_fields"]["lg_pdf_view"])
    else
      return nil
    end
  end

  # Switch between different attachment file types
  def attachment_file_format_switcher(file)
    file_type = get_file_type(file).downcase
    download_name = gen_download_link_name(file)

    case file_type
    when ".jpg", ".jpeg", ".gif", ".png", ".bmp"
      render partial: "docs/fields/file_types/image", locals: { file: file, download_name: download_name }
    when ".pdf"
      render partial: "docs/fields/file_types/pdf", locals: { file: file, download_name: download_name }
    when "doc_cloud"
      render partial: "docs/fields/file_types/doc_cloud", locals: { file: file }
    when ".html", ".htm", ".txt", ".svg", ".mp4"
      render partial: "docs/fields/file_types/iframe", locals: { file: file, download_name: download_name }
    when ".doc", ".docx", ".odt", ".rtf", ".wbk", ".ppt", ".pptx", ".odp", ".xls", ".xlsx", ".ods"
      lg_pdf_view = get_alt_attachment_path
      render partial: "docs/fields/file_types/office_doc", locals: {file: file, download_name: download_name, lg_pdf_view: lg_pdf_view}
    else
      render partial: "docs/fields/file_types/download", locals: { file: file, download_name: download_name }
    end
  end
end
