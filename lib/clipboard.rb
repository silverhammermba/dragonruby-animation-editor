module Clipboard
  def self.paste
    $gtk.ffi_misc.getclipboard
  end

  def self.copy str
    # brute-force copy!
    programs = [
      ['clip', 259],
      ['pbcopy', 0],
      ['xclip -selection clipboard', 0],
      ['wl-copy', 0],
    ]
    success = false
    programs.each do |prog, code|
      begin
        IO.popen(prog, 'w+') { |f| f << str }
        success ||= $? == code
      rescue
      end
    end
    unless success
      raise "Failed to copy. Do you need to install xclip or wl-clipboard?"
    end
  end
end
