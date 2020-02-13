classdef ijRoi
    % based on https://imagej.nih.gov/ij/developer/source/ij/io/RoiDecoder.java.html
    
    properties
        filename
        filepath
        info
        options
        x
        y
        rawData
    end
    properties (Hidden)
        filesize
    end
    properties (Constant, Hidden)
        % offsets
        VERSION_OFFSET = int32(4);
        TYPE = int32(6);
        TOP = int32(8);
        LEFT = int32(10);
        BOTTOM = int32(12);
        RIGHT = int32(14);
        N_COORDINATES = int32(16);
        X1 = int32(18);
        Y1 = int32(22);
        X2 = int32(26);
        Y2 = int32(30);
        XD = int32(18);
        YD = int32(22);
        WIDTHD = int32(26);
        HEIGHTD = int32(30);
        SIZE = int32(18);
        STROKE_WIDTH = int32(34);
        SHAPE_ROI_SIZE = int32(36);
        STROKE_COLOR = int32(40);
        FILL_COLOR = int32(44);
        SUBTYPE = int32(48);
        OPTIONS = int32(50);
        ARROW_STYLE = int32(52);
        FLOAT_PARAM = int32(52); %ellipse ratio or rotated rect width
        POINT_TYPE= int32(52);
        ARROW_HEAD_SIZE = int32(53);
        ROUNDED_RECT_ARC_SIZE = int32(54);
        POSITION = int32(56);
        HEADER2_OFFSET = int32(60);
        COORDINATES = int32(64);
        % header2 offsets
        C_POSITION = int32(4);
        Z_POSITION = int32(8);
        T_POSITION = int32(12);
        NAME_OFFSET = int32(16);
        NAME_LENGTH = int32(20);
        OVERLAY_LABEL_COLOR = int32(24);
        OVERLAY_FONT_SIZE = int32(28); %short
        GROUP = int32(30);  %byte
        IMAGE_OPACITY = int32(31);  %byte
        IMAGE_SIZE = int32(32);  %int
        FLOAT_STROKE_WIDTH = int32(36);  %float
        ROI_PROPS_OFFSET = int32(40);
        ROI_PROPS_LENGTH = int32(44);
        COUNTERS_OFFSET = int32(48);
        % file extension
        EXTENSION = '.roi'
    end
    
    methods
        function obj = ijRoi(filename)
            if isstruct(filename) %file as structure
                filename = fullfile(filename.folder,filename.name);
            end
            if strcmp(filename(end-3:end),'.zip')
                warning('no support for .zip\n Please unpack first to idividual .rois');
                files = unzip(filename,'temp');
                for ct = 1:length(files)
                    obj(ct) = ijRoi(fullfile(cd,files{ct}));
                    delete(fullfile(cd,files{ct}));
                end
                rmdir('temp')
                return;
            end
            if ~strcmp(filename(end-3:end),obj.EXTENSION),filename=[filename,obj.EXTENSION];end
            if ~exist(filename,'file')
                error('cannot find file')
            else
                fid = fopen(filename,'r','l');
            end
            %get data
            d = dir(filename);
            obj.filesize = d.bytes;
            obj.filename = d.name;
            obj.filepath = d.folder;
            rawData = fread(fid,inf,'*uint8');
            obj.rawData=rawData;
            fclose(fid);
            
            assert(rawData(1)==73,'Not a valid roi file');
            obj.info.version = obj.getShort(rawData,obj.VERSION_OFFSET);
            obj.info.type = obj.roiType(obj.getByte(rawData,obj.TYPE));
            obj.info.subtype = obj.roiSubType(obj.getShort(rawData,obj.SUBTYPE));
            obj.info.top= obj.getShort(rawData,obj.TOP);
            obj.info.left = obj.getShort(rawData,obj.LEFT);
            obj.info.bottom = obj.getShort(rawData,obj.BOTTOM);
            obj.info.right = obj.getShort(rawData,obj.RIGHT);
            obj.info.width = obj.info.right-obj.info.left;
            obj.info.height = obj.info.bottom-obj.info.top;
            obj.info.n = obj.getShort(rawData,obj.N_COORDINATES);
            if (obj.info.n==0)
                obj.info.n = obj.getInt(rawData,obj.SIZE);
            end
            obj.options = obj.splitOptions(obj.getShort(rawData,obj.OPTIONS));
            obj.info.position = obj.getInt(rawData,obj.POSITION);
            obj.info.hdr2Offset = obj.getInt(rawData,obj.HEADER2_OFFSET);
            
            if any(ismember(obj.info.type,{'polygon', 'freeline', 'polyline', 'freehand', 'traced', 'angle', 'point'}))
                if obj.options.subPixelResolution
                    base1 = single(obj.COORDINATES)+single(4*obj.info.n);
                    base2 = base1 + 4*single(obj.info.n);
                    for pt = 1:obj.info.n
                        obj.x(pt) = single(obj.getFloat(rawData,base1+single((pt-1)*4)));
                        obj.y(pt) = single(obj.getFloat(rawData,base2+single((pt-1)*4)));
                    end
                else
                    base1 = int32(obj.COORDINATES);
                    base2 = base1 + int32(2*obj.info.n);
                    for pt = 1:obj.info.n
                        obj.x(pt) = int32(obj.getShort(rawData,base1+int32((pt-1)*2)))+int32(obj.info.left);
                        obj.y(pt) = int32(obj.getShort(rawData,base2+int32((pt-1)*2)))+int32(obj.info.top);
                    end
                end
            else %could implement subPixel rect, oval . 
                warning('no support for %s\n',obj.info.type)
            end
        end
        function [] = plot(obj)
            hold on
            for ct=1:length(obj)
                plot(obj(ct).x,obj(ct).y,'.-')
                set(gca,'ydir','reverse')
            end
            hold off
        end
    end
    methods(Static, Hidden)
        function options = splitOptions(in)
            names = {'splineFit';'doubleHeaded';'outline';'overlayLabels';'overlayNames';'overlayBackgrounds';'overlayBold';'subPixelResolution';'drawOffset';'zeroTransparent';'showLabels';'scaleLabels';'promptBeforeDeleting'};
            for ct = 1:length(names)
                options.(names{ct}) = bitget(in,ct)==1;
            end
        end
        function out = getByte(dat,in)
            in=in+1;
            out = dat(in);
        end
        function out = getShort(dat,in)
            in=in+1;
            out = typecast(dat(in+1:-1:in),'uint16');
        end
        function out = getInt(dat,in)
            in=in+1;
            out = typecast(dat(in+3:-1:in),'int32');
        end
        function out = getFloat(dat,in)
            in=in+1;
            out = typecast(dat(in+3:-1:in),'single');
        end
        function out = roiSubType(in)
            types = {'none','text','arrow','ellipse','image','rotated_rect'};
            if isnumeric(in)
                out = types{in+1};
            else
                out = find(ismember(types,in))-1;
            end
        end
        function out = roiType(in)
            types = {'polygon', 'rect', 'oval', 'line', 'freeline', 'polyline', 'noRoi', 'freehand', 'traced', 'angle', 'point'};
            if isnumeric(in)
                out = types{in+1};
            else
                out = find(ismember(types,in))-1;
            end
        end
    end
end