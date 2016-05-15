module Rescpos
	module ReportUtil
		FONT_NORMAL = "\x00"
		FONT_BIG = "\x11"
		WEIGHT_BOLD = "\x08"
		WEIGHT_NORMAL = "\x00"
		ALIGN_C = "\x01"
		ALIGN_L = "\x00"
		ALIGN_R = "\x02"
		BARCODE_UPCA = 65
		BARCODE_UPCE = 66
		BARCODE_EAN13 = 67
		BARCODE_EAN8 = 68
		BARCODE_CODE39 = 69
		BARCODE_ITF = 70
		BARCODE_CODABAR = 71
		BARCODE_CODE93 = 72
		BARCODE_CODE128 = 73

		def single_splitline
			text("-" * 42, :font_size => FONT_NORMAL)
		end

		def double_splitline
			text("=" * 42, :font_size => FONT_NORMAL)
		end

		def underline(number)
			text("_" * number, :font_size => FONT_NORMAL)
		end

		def chinese(chinese)
			text = string.encode('GBK', 'UTF-8', :invalid => :replace, :undef => :replace, :replace => '')
			#text = Iconv.iconv("GBK//IGNORE","UTF-8//IGNORE",chinese)
			text[0]
		end

		def text(txt, options = {}) 
			font_size = options[:font_size] || FONT_NORMAL
			formatted_text = ''
			formatted_text << weight(options[:weight]) if options[:weight]
			formatted_text << fontsize(font_size)
			formatted_text << grayscale(options[:gray]) if options[:gray]
			formatted_text << align(options[:align_type]) if options[:align_type]
			formatted_text << txt if txt
		end
		
		def weight(bold)
			"\x1b\x21" << bold.to_s
		end

		def fontsize(size)
			"\x1d\x21" << size.to_s
		end

		def grayscale(value)
			"\x1b\x6d" << ascii(value)
		end

		def key_value(label, value)
			"#{label}: #{value}"
		end

		def align(type)
			"\x1b\x61" << type.to_s
		end
		
		def table(data)
			table = Rescpos::Table.new(data)
			yield table
			# FIXME move the following logic into Rescpos::Table
			command = "\x1b\x44"
			table.positions.each do |position|
				command << position.chr
			end
			command << "\x00"
			if table.headers
				table.headers.each do |header|
					command << header << "\x09" 
				end
				command << "\n"
			end
			table.data.each do |item|
				if item.is_a? Array
					command = command + item.join("\x09") + (table.data.last == item ? "" : "\n")
				else
					table.keys.each do |key|
						if item.is_a? Hash
							command << "#{item[key]}\x09"
						else
							command << "#{item.send(key)}\x09"
						end
					end
					if table.data.last == item
						return command
					end
					command << "\n"
				end
			end
			command
		end

		def horizontal_tab
			"\x09"
		end
		
		def ascii(value)
			value.to_s.unpack('U')[0].to_s(16)
		end

		def full_cut
			"\n\x1d\x56#{65.chr}\x0c"
		end

		def partial_cut
			"\n\x1d\x56#{66.chr}\x0c"
		end

		def barcode(code, options)
			"\n\x1d\x77\x02\x1d\x48\x02\x1d\x6b#{options[:type].chr}#{code.size.chr}#{code}"
		end

		def image(image_file)
			# GS v 
			base_store_command = "\x1d\x76\x30\x00" +
			commands = ''
			image = ::Magick::Image::read(image_file).first
			if image
				if image.columns > 2047 || image.rows > 1662
					image.resize_to_fit!(2047, 1662)
				end
				if image.depth > 1
					image = image.quantize(2)
				end
				width = image.columns >> 3
				height = image.columns >> 3
				image = image.extent(width*8, height*8)
				image_bytes = image.export_pixels
				bitmap = []
				counter = 0
				temp = 0
				mask = 0x80
				(width * height * 8 * 3 * 8).times do |b|
					next unless (b % 3).zero?
					temp |= mask if image_bytes[b] == 0
					mask = mask >> 1
					counter += 3
					if counter == 24
						bitmap << temp
						mask = 0x80
						counter = 0
						temp = 0
					end
				end
				commands << base_store_command
				commands << [width, height*8].pack('SS')
				commands << bitmap.pack('C*')
			end
			commands.force_encoding('UTF-8')
		end
		def image2(image_file)
			# GS 8 L function 112
			base_store_command = "\x1d\x38\x4c" +
				# p1 p2 p3 p4
				"\x00\x00\x00\x00" +
				# m fn
				"\x30\x70" +
				# a bx by c
				"\x30\x01\x01\x31" +
				# xL xH yL yH
				"\x00\x00\x00\x00"
			# GS ( L function 50
			print_command = "\x1d\x28\x4c\x02\x00\x30\x32"
			commands = ''
			image = ::Magick::Image::read(image_file).first
			if image
				if image.columns > 2047 || image.rows > 1662
					image.resize_to_fit!(2047, 1662)
				end
				if image.depth > 1
					image = image.quantize(2)
				end
				width = image.columns >> 3
				height = image.columns >> 3
				image = image.extent(width*8, height*8)
				image_bytes = image.export_pixels(0, 0, image.columns, image.rows, 'I')
				bitmap = []
				counter = 0
				temp = 0
				mask = 0x80
				image_bytes.size.times do |b|
					temp |= mask if image_bytes[b] == 0
					mask = mask >> 1
					counter += 1
					if counter == 8
						bitmap << temp
						mask = 0x80
						counter = 0
						temp = 0
					end
				end
				commands << base_store_command
				commands << bitmap.pack('C*')
				commands << print_command
				p = (image_bytes.size + 9).to_s(16).rjust(8, '0')
				commands[3] = p[-2..-1].to_i(16).chr
				commands[4] = p[-4..-3].to_i(16).chr
				commands[5] = p[-6..-5].to_i(16).chr
				commands[6] = p[-8..-7].to_i(16).chr
				commands[13] = image.columns.to_s(16).rjust(4, '0')[-2..-1].to_i(16).chr
				commands[14] = image.columns.to_s(16).rjust(4, '0')[-4..-3].to_i(16).chr
				commands[15] = image.rows.to_s(16).rjust(4, '0')[-2..-1].to_i(16).chr
				commands[16] = image.rows.to_s(16).rjust(4, '0')[-4..-3].to_i(16).chr
			end
			commands.force_encoding('UTF-8')
		end
	end
end
