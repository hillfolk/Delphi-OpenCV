(*
  * filter layer
  * Copyright (c) 2007 Bobby Bingham
  *
  * This file is part of ffm.
  *
  * FFmpeg is free software; you can redistribute it and/or
  * modify it under the terms of the GNU Lesser General Public
  * License as published by the Free Software Foundation; either
  * version 2.1 of the License, or (at your option) any later version.
  *
  * FFmpeg is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  * Lesser General Public License for more details.
  *
  * You should have received a copy of the GNU Lesser General Public
  * License along with FFmpeg; if not, write to the Free Software
  * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*)

unit ffm.avfilter;

{$i ffmpeg.inc}

interface

uses
  ffm.log, ffm.dict, ffm.rational, ffm.avutil, ffm.frame;

(*
  * Return the LIBAVFILTER_VERSION_INT constant.
*)
// unsigned avfilter_version(void);

(*
  * Return the libavfilter build-time configuration.
*)
// const char *avfilter_configuration(void);

(*
  * Return the libavfilter license.
*)
// const char *avfilter_license(void);

{$IFDEF FF_API_AVFILTERBUFFER}

const
  AV_PERM_READ = $01;
  /// < can read from the buffer
  AV_PERM_WRITE = $02;
  /// < can write to the buffer
  AV_PERM_PRESERVE = $04;
  /// < nobody else can overwrite the buffer
  AV_PERM_REUSE = $08;
  /// < can output the buffer multiple times, with the same contents each time
  AV_PERM_REUSE2 = $10;
  /// < can output the buffer multiple times, modified each time
  AV_PERM_NEG_LINESIZES = $20;
  /// < the buffer requested can have negative linesizes
  AV_PERM_ALIGN = $40;
  /// < the buffer must be aligned

  AVFILTER_ALIGN = 16; // not part of ABI
{$ENDIF}

Type
  ppByte = ^pByte;

  pAVFilterLink = ^TAVFilterLink;
  ppAVFilterLink = ^pAVFilterLink;

  pAVFilterPad = ^TAVFilterPad;

  TAVFilterPad = record

  end;

  pAVFilterFormats = ^TAVFilterFormats;

  TAVFilterFormats = record

  end;

{$IFDEF FF_API_AVFILTERBUFFER}

  (*
    * A reference-counted buffer data type used by the filter system. Filters
    * should not store pointers to this structure directly, but instead use the
    * AVFilterBufferRef structure below.
  *)
  pAVFilterBuffer = ^TAVFilterBuffer;

  TAVFilterBuffer = record
    data: array [0 .. 7] of pByte;
    /// < buffer data for each plane/channel

    (*
      * pointers to the data planes/channels.
      *
      * For video, this should simply point to data[].
      *
      * For planar audio, each channel has a separate data pointer, and
      * linesize[0] contains the size of each channel buffer.
      * For {packed} audio, there is just one data pointer, and linesize[0]
      * contains the total size of the buffer for all channels.
      *
      * Note: Both data and extended_data will always be set, but for planar
      * audio with more channels that can fit in data, extended_data must be used
      * in order to access all channels.
    *)
    extended_data: ppByte;
    linesize: array [0 .. 7] of integer;
    /// < number of bytes per line

    (* private data to be used by a custom free function *)
    priv: pointer;
    (*
      * A pointer to the function to deallocate this buffer if the default
      * function is not sufficient. This could, for example, add the memory
      * back into a memory pool to be reused later without the overhead of
      * reallocating it from scratch.
    *)
    // void (*free)(struct AVFilterBuffer *buf);
    free: procedure(buf: pAVFilterBuffer); cdecl;

    format: integer;
    /// < media format
    w, h: integer;
    /// < width and height of the allocated buffer
    refcount: cardinal;
    /// < number of references to this buffer
  end;

  (*
    * Audio specific properties in a reference to an AVFilterBuffer. Since
    * AVFilterBufferRef is common to different media formats, audio specific
    * per reference properties must be separated out.
  *)
  pAVFilterBufferRefAudioProps = ^TAVFilterBufferRefAudioProps;

  TAVFilterBufferRefAudioProps = record
    channel_layout: uint64;
    /// < channel layout of audio buffer
    nb_samples: integer;
    /// < number of audio samples per channel
    sample_rate: integer;
    /// < audio buffer sample rate
    channels: integer;
    /// < number of channels (do not access directly)
  end;

  (*
    * Video specific properties in a reference to an AVFilterBuffer. Since
    * AVFilterBufferRef is common to different media formats, video specific
    * per reference properties must be separated out.
  *)
  pAVFilterBufferRefVideoProps = ^TAVFilterBufferRefVideoProps;

  TAVFilterBufferRefVideoProps = record
    w: integer;
    /// < image width
    h: integer;
    /// < image height
    sample_aspect_ratio: TAVRational;
    /// < sample aspect ratio
    interlaced: integer;
    /// < is frame interlaced
    top_field_first: integer;
    /// < field order
    pict_type: TAVPictureType;
    /// < picture type of the frame
    key_frame: integer;
    /// < 1 -> keyframe, 0-> not
    qp_table_linesize: integer;
    /// < qp_table stride
    qp_table_size: integer;
    /// < qp_table size
    qp_table: pByte;
    /// < array of Quantization Parameters
  end;

  (*
    * A reference to an AVFilterBuffer. Since filters can manipulate the origin of
    * a buffer to, for example, crop image without any memcpy, the buffer origin
    * and dimensions are per-reference properties. Linesize is also useful for
    * image flipping, frame to field filters, etc, and so is also per-reference.
    *
    * TODO: add anything necessary for frame reordering
  *)
  pAVFilterBufferRef = ^TAVFilterBufferRef;

  TAVFilterBufferRef = record
    buf: pAVFilterBuffer;
    /// < the buffer that this is a reference to
    data: array [0 .. 7] of pByte;
    /// < picture/audio data for each plane
    (*
      * pointers to the data planes/channels.
      *
      * For video, this should simply point to data[].
      *
      * For planar audio, each channel has a separate data pointer, and
      * linesize[0] contains the size of each channel buffer.
      * For {packed} audio, there is just one data pointer, and linesize[0]
      * contains the total size of the buffer for all channels.
      *
      * Note: Both data and extended_data will always be set, but for planar
      * audio with more channels that can fit in data, extended_data must be used
      * in order to access all channels.
    *)
    extended_data: ppByte;
    linesize: array [0 .. 7] of integer;
    /// < number of bytes per line

    video: pAVFilterBufferRefVideoProps;
    /// < video buffer specific properties
    audio: pAVFilterBufferRefAudioProps;
    /// < audio buffer specific properties

    (*
      * presentation timestamp. The time unit may change during
      * filtering, as it is specified in the link and the filter code
      * may need to rescale the PTS accordingly.
    *)
    pts: int64;
    pos: int64;
    /// < byte position in stream, -1 if unknown

    format: integer;
    /// < media format

    perms: integer;
    /// < permissions, see the AV_PERM_* flags

    _type: TAVMediaType;
    /// < media type of buffer data

    metadata: pAVDictionary;
    /// < dictionary containing metadata key=value tags
  end;
  //
  // (*
  // * Copy properties of src to dst, without copying the actual data
  // *)
  // attribute_deprecated void avfilter_copy_buffer_ref_props(AVFilterBufferRef * dst, AVFilterBufferRef * src);
  //
  // (*
  // * Add a new reference to a buffer.
  // *
  // * @param ref   an existing reference to the buffer
  // * @param pmask a bitmask containing the allowable permissions in the new
  // *              reference
  // * @return      a new reference to the buffer with the same properties as the
  // *              old, excluding any permissions denied by pmask
  // *)
  // attribute_deprecated AVFilterBufferRef * avfilter_ref_buffer(AVFilterBufferRef * ref, int pmask);
  //
  // (*
  // * Remove a reference to a buffer. If this is the last reference to the
  // * buffer, the buffer itself is also automatically freed.
  // *
  // * @param ref reference to the buffer, may be NULL
  // *
  // * @note it is recommended to use avfilter_unref_bufferp() instead of this
  // * function
  // *)
  // attribute_deprecated void avfilter_unref_buffer(AVFilterBufferRef * ref);
  //
  // (*
  // * Remove a reference to a buffer and set the pointer to NULL.
  // * If this is the last reference to the buffer, the buffer itself
  // * is also automatically freed.
  // *
  // * @param ref pointer to the buffer reference
  // *)
  // attribute_deprecated void avfilter_unref_bufferp(AVFilterBufferRef * * ref);
{$ENDIF}
  //
  // (*
  // * Get the number of channels of a buffer reference.
  // *)
  // attribute_deprecated int avfilter_ref_get_channels(AVFilterBufferRef * ref);
  //
  // #
  // if FF_API_AVFILTERPAD_PUBLIC
  // (*
  // * A filter pad used for either input or output.
  // *
  // * See doc/filter_design.txt for details on how to implement the methods.
  // *
  // * @warning this struct might be removed from public API.
  // * users should call avfilter_pad_get_name() and avfilter_pad_get_type()
  // * to access the name and type fields; there should be no need to access
  // * any other fields from outside of libavfilter.
  // *)
  // struct AVFilterPad {
  // (*
  // * Pad name. The name is unique among inputs and among outputs, but an
  // * input may have the same name as an output. This may be NULL if this
  // * pad has no need to ever be referenced by name.
  // *)
  // const char *name;
  //
  // (*
  // * AVFilterPad type.
  // *)
  // enum AVMediaType type;
  //
  // (*
  // * Input pads:
  // * Minimum required permissions on incoming buffers. Any buffer with
  // * insufficient permissions will be automatically copied by the filter
  // * system to a new buffer which provides the needed access permissions.
  // *
  // * Output pads:
  // * Guaranteed permissions on outgoing buffers. Any buffer pushed on the
  // * link must have at least these permissions; this fact is checked by
  // * asserts. It can be used to optimize buffer allocation.
  // *)
  // attribute_deprecated int min_perms;
  //
  // (*
  // * Input pads:
  // * Permissions which are not accepted on incoming buffers. Any buffer
  // * which has any of these permissions set will be automatically copied
  // * by the filter system to a new buffer which does not have those
  // * permissions. This can be used to easily disallow buffers with
  // * AV_PERM_REUSE.
  // *
  // * Output pads:
  // * Permissions which are automatically removed on outgoing buffers. It
  // * can be used to optimize buffer allocation.
  // *)
  // attribute_deprecated int rej_perms;
  //
  // (*
  // * @deprecated unused
  // *)
  // int (*start_frame)(AVFilterLink *link, AVFilterBufferRef *picref);
  //
  // (*
  // * Callback function to get a video buffer. If NULL, the filter system will
  // * use ff_default_get_video_buffer().
  // *
  // * Input video pads only.
  // *)
  // AVFrame *(*get_video_buffer)(AVFilterLink *link, int w, int h);
  //
  // (*
  // * Callback function to get an audio buffer. If NULL, the filter system will
  // * use ff_default_get_audio_buffer().
  // *
  // * Input audio pads only.
  // *)
  // AVFrame *(*get_audio_buffer)(AVFilterLink *link, int nb_samples);
  //
  // (*
  // * @deprecated unused
  // *)
  // int (*end_frame)(AVFilterLink *link);
  //
  // (*
  // * @deprecated unused
  // *)
  // int (*draw_slice)(AVFilterLink *link, int y, int height, int slice_dir);
  //
  // (*
  // * Filtering callback. This is where a filter receives a frame with
  // * audio/video data and should do its processing.
  // *
  // * Input pads only.
  // *
  // * @return >= 0 on success, a negative AVERROR on error. This function
  // * must ensure that frame is properly unreferenced on error if it
  // * hasn't been passed on to another filter.
  // *)
  // int (*filter_frame)(AVFilterLink *link, AVFrame *frame);
  //
  // (*
  // * Frame poll callback. This returns the number of immediately available
  // * samples. It should return a positive value if the next request_frame()
  // * is guaranteed to return one frame (with no delay).
  // *
  // * Defaults to just calling the source poll_frame() method.
  // *
  // * Output pads only.
  // *)
  // int (*poll_frame)(AVFilterLink *link);
  //
  // (*
  // * Frame request callback. A call to this should result in at least one
  // * frame being output over the given link. This should return zero on
  // * success, and another value on error.
  // * See ff_request_frame() for the error codes with a specific
  // * meaning.
  // *
  // * Output pads only.
  // *)
  // int (*request_frame)(AVFilterLink *link);
  //
  // (*
  // * Link configuration callback.
  // *
  // * For output pads, this should set the following link properties:
  // * video: width, height, sample_aspect_ratio, time_base
  // * audio: sample_rate.
  // *
  // * This should NOT set properties such as format, channel_layout, etc which
  // * are negotiated between filters by the filter system using the
  // * query_formats() callback before this function is called.
  // *
  // * For input pads, this should check the properties of the link, and update
  // * the filter's internal state as necessary.
  // *
  // * For both input and output pads, this should return zero on success,
  // * and another value on error.
  // *)
  // int (*config_props)(AVFilterLink *link);
  //
  // (*
  // * The filter expects a fifo to be inserted on its input link,
  // * typically because it has a delay.
  // *
  // * input pads only.
  // *)
  // int needs_fifo;
  //
  // int needs_writable;
  // };
  // # endif
  //
  // (*
  // * Get the number of elements in a NULL-terminated array of AVFilterPads (e.g.
  // * AVFilter.inputs/outputs).
  // *)
  // int avfilter_pad_count(const AVFilterPad * pads);
  //
  // (*
  // * Get the name of an AVFilterPad.
  // *
  // * @param pads an array of AVFilterPads
  // * @param pad_idx index of the pad in the array it; is the caller's
  // *                responsibility to ensure the index is valid
  // *
  // * @return name of the pad_idx'th pad in pads
  // *)
  // const
  // char * avfilter_pad_get_name(const AVFilterPad * pads, int pad_idx);
  //
  // (*
  // * Get the type of an AVFilterPad.
  // *
  // * @param pads an array of AVFilterPads
  // * @param pad_idx index of the pad in the array; it is the caller's
  // *                responsibility to ensure the index is valid
  // *
  // * @return type of the pad_idx'th pad in pads
  // *)
  // enum AVMediaType avfilter_pad_get_type(const AVFilterPad * pads, int pad_idx);
  //
  // (*
  // * The number of the filter inputs is not determined just by AVFilter.inputs.
  // * The filter might add additional inputs during initialization depending on the
  // * options supplied to it.
  // *)
  // # define AVFILTER_FLAG_DYNAMIC_INPUTS(1 << 0)
  // (*
  // * The number of the filter outputs is not determined just by AVFilter.outputs.
  // * The filter might add additional outputs during initialization depending on
  // * the options supplied to it.
  // *)
  // # define AVFILTER_FLAG_DYNAMIC_OUTPUTS(1 << 1)
  // (*
  // * The filter supports multithreading by splitting frames into multiple parts
  // * and processing them concurrently.
  // *)
  // # define AVFILTER_FLAG_SLICE_THREADS(1 << 2)
  // (*
  // * Some filters support a generic "enable" expression option that can be used
  // * to enable or disable a filter in the timeline. Filters supporting this
  // * option have this flag set. When the enable expression is false, the default
  // * no-op filter_frame() function is called in place of the filter_frame()
  // * callback defined on each input pad, thus the frame is passed unchanged to
  // * the next filters.
  // *)
  // # define AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC(1 << 16)
  // (*
  // * Same as AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC, except that the filter will
  // * have its filter_frame() callback(s) called as usual even when the enable
  // * expression is false. The filter will disable filtering within the
  // * filter_frame() callback(s) itself, for example executing code depending on
  // * the AVFilterContext->is_disabled value.
  // *)
  // # define AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL(1 << 17)
  // (*
  // * Handy mask to test whether the filter supports or no the timeline feature
  // * (internally or generically).
  // *)
  // # define AVFILTER_FLAG_SUPPORT_TIMELINE(AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC | AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL)

  (*
    * Filter definition. This defines the pads a filter contains, and all the
    * callback functions used to interact with the filter.
  *)
  pAVFilterContext = ^TAVFilterContext;
  ppAVFilterContext = ^pAVFilterContext;

  pavfilter = ^Tavfilter;

  Tavfilter = record
    (*
      * Filter name. Must be non-NULL and unique among filters.
    *)
    name: pAnsiChar;

    (*
      * A description of the filter. May be NULL.
      *
      * You should use the NULL_IF_CONFIG_SMALL() macro to define it.
    *)
    description: pAnsiChar;

    (*
      * List of inputs, terminated by a zeroed element.
      *
      * NULL if there are no (static) inputs. Instances of filters with
      * AVFILTER_FLAG_DYNAMIC_INPUTS set may have more inputs than present in
      * this list.
    *)
    inputs: pAVFilterPad;
    (*
      * List of outputs, terminated by a zeroed element.
      *
      * NULL if there are no (static) outputs. Instances of filters with
      * AVFILTER_FLAG_DYNAMIC_OUTPUTS set may have more outputs than present in
      * this list.
    *)
    outputs: pAVFilterPad;

    (*
      * A class for the private data, used to declare filter private AVOptions.
      * This field is NULL for filters that do not declare any options.
      *
      * If this field is non-NULL, the first member of the filter private data
      * must be a pointer to AVClass, which will be set by libavfilter generic
      * code to this class.
    *)
    priv_class: pAVClass;

    (*
      * A combination of AVFILTER_FLAG_*
    *)
    flags: integer;

    (* ***************************************************************
      * All fields below this line are not part of the public API. They
      * may not be used outside of libavfilter and can be changed and
      * removed at will.
      * New public fields should be added right above.
      *****************************************************************
    *)

    (*
      * Filter initialization function.
      *
      * This callback will be called only once during the filter lifetime, after
      * all the options have been set, but before links between filters are
      * established and format negotiation is done.
      *
      * Basic filter initialization should be done here. Filters with dynamic
      * inputs and/or outputs should create those inputs/outputs here based on
      * provided options. No more changes to this filter's inputs/outputs can be
      * done after this callback.
      *
      * This callback must not assume that the filter links exist or frame
      * parameters are known.
      *
      * @ref AVFilter.uninit "uninit" is guaranteed to be called even if
      * initialization fails, so this callback does not have to clean up on
      * failure.
      *
      * @return 0 on success, a negative AVERROR on failure
    *)
    // int (*init)(AVFilterContext *ctx);
    init:

      function(ctx: pAVFilterContext): integer; cdecl;

    (*
      * Should be set instead of @ref AVFilter.init "init" by the filters that
      * want to pass a dictionary of AVOptions to nested contexts that are
      * allocated during init.
      *
      * On return, the options dict should be freed and replaced with one that
      * contains all the options which could not be processed by this filter (or
      * with NULL if all the options were processed).
      *
      * Otherwise the semantics is the same as for @ref AVFilter.init "init".
    *)
    // int (*init_dict)(AVFilterContext *ctx, AVDictionary **options);
    init_dict: function(ctx: pAVFilterContext; options: ppAVDictionary): integer; cdecl;

    (*
      * Filter uninitialization function.
      *
      * Called only once right before the filter is freed. Should deallocate any
      * memory held by the filter, release any buffer references, etc. It does
      * not need to deallocate the AVFilterContext.priv memory itself.
      *
      * This callback may be called even if @ref AVFilter.init "init" was not
      * called or failed, so it must be prepared to handle such a situation.
    *)
    // void (*uninit)(AVFilterContext *ctx);
    uninit: procedure(ctx: pAVFilterContext); cdecl;

    (*
      * Query formats supported by the filter on its inputs and outputs.
      *
      * This callback is called after the filter is initialized (so the inputs
      * and outputs are fixed), shortly before the format negotiation. This
      * callback may be called more than once.
      *
      * This callback must set AVFilterLink.out_formats on every input link and
      * AVFilterLink.in_formats on every output link to a list of pixel/sample
      * formats that the filter supports on that link. For audio links, this
      * filter must also set @ref AVFilterLink.in_samplerates "in_samplerates" /
      * @ref AVFilterLink.out_samplerates "out_samplerates" and
      * @ref AVFilterLink.in_channel_layouts "in_channel_layouts" /
      * @ref AVFilterLink.out_channel_layouts "out_channel_layouts" analogously.
      *
      * This callback may be NULL for filters with one input, in which case
      * libavfilter assumes that it supports all input formats and preserves
      * them on output.
      *
      * @return zero on success, a negative value corresponding to an
      * AVERROR code otherwise
    *)
    // int (*query_formats)(AVFilterContext *);
    query_formats: function(fc: pAVFilterContext): integer; cdecl;

    priv_size: integer;
    /// < size of private data to allocate for the filter

    (*
      * Used by the filter registration system. Must not be touched by any other
      * code.
    *)
    next: pavfilter;

    (*
      * Make the filter instance process a command.
      *
      * @param cmd    the command to process, for handling simplicity all commands must be alphanumeric only
      * @param arg    the argument for the command
      * @param res    a buffer with size res_size where the filter(s) can return a response. This must not change when the command is not supported.
      * @param flags  if AVFILTER_CMD_FLAG_FAST is set and the command would be
      *               time consuming then a filter should treat it like an unsupported command
      *
      * @returns >=0 on success otherwise an error code.
      *          AVERROR(ENOSYS) on unsupported commands
    *)
    // int (*process_command)(AVFilterContext *, const char *cmd, const char *arg, char *res, int res_len, int flags);
    process_command: function(fc: pAVFilterContext; const cmd: pAnsiChar; const arg: pAnsiChar; res: pAnsiChar; res_len: integer;
      flags: integer): integer; cdecl;

    (*
      * Filter initialization function, alternative to the init()
      * callback. Args contains the user-supplied parameters, opaque is
      * used for providing binary data.
    *)
    // int (*init_opaque)(AVFilterContext *ctx, void *opaque);
    init_opaque: function(ctx: pAVFilterContext; opaque: pointer): integer; cdecl;
  end;

  (*
    * Process multiple parts of the frame concurrently.
  *)
  // # define AVFILTER_THREAD_SLICE(1 << 0)

  pAVFilterInternal = ^TAVFilterInternal;

  TAVFilterInternal = record

  end;

  pAVFilterCommand = ^TAVFilterCommand;

  TAVFilterCommand = record

  end;

  pAVFilterGraph = ^TAVFilterGraph;

  (* An instance of a filter *)
  TAVFilterContext = record
    av_class: pAVClass;
    /// < needed for av_log() and filters common options
    filter: pavfilter;
    /// < the AVFilter of which this is an instance
    name: pAnsiChar;
    /// < name of this filter instance
    input_pads: pAVFilterPad;
    /// < array of input pads
    inputs: ppAVFilterLink;
    /// < array of pointers to input links
{$IFDEF FF_API_FOO_COUNT}
    // attribute_deprecated
    input_count: cardinal;
    /// < @deprecated use nb_inputs
{$ENDIF}
    nb_inputs: cardinal;
    /// < number of input pads
    output_pads: pAVFilterPad;
    /// < array of output pads
    outputs: ppAVFilterLink;
    /// < array of pointers to output links
{$IFDEF FF_API_FOO_COUNT}
    // attribute_deprecated
    output_count: cardinal;
    /// < @deprecated use nb_outputs
{$ENDIF}
    nb_outputs: cardinal;
    /// < number of output pads
    priv: pointer;
    /// < private data for use by the filter
    graph: pAVFilterGraph;
    /// < filtergraph this filter belongs to
    (*
      * Type of multithreading being allowed/used. A combination of
      * AVFILTER_THREAD_* flags.
      *
      * May be set by the caller before initializing the filter to forbid some
      * or all kinds of multithreading for this filter. The default is allowing
      * everything.
      *
      * When the filter is initialized, this field is combined using bit AND with
      * AVFilterGraph.thread_type to get the final mask used for determining
      * allowed threading types. I.e. a threading type needs to be set in both
      * to be allowed.
      *
      * After the filter is initialzed, libavfilter sets this field to the
      * threading type that is actually used (0 for no multithreading).
    *)
    thread_type: integer;
    (*
      * An opaque struct for libavfilter internal use.
    *)
    internal: pAVFilterInternal;
    command_queue: pAVFilterCommand;
    enable_str: pAnsiChar;
    /// < enable expression string
    enable: pointer;
    /// < parsed expression (AVExpr*)
    var_values: pDouble;
    /// < variable values for the enable expression
    is_disabled: integer;
    /// < the enabled state from the last expression evaluation
  end;

  (*
    * A link between two filters. This contains pointers to the source and
    * destination filters between which this link exists, and the indexes of
    * the pads involved. In addition, this link also contains the parameters
    * which have been negotiated and agreed upon between the filter, such as
    * image dimensions, format, etc.
  *)
  Tinit_state = ( //
    AVLINK_UNINIT = 0,
    /// < not started
    AVLINK_STARTINIT,
    /// < started, but incomplete
    AVLINK_INIT
    /// < complete
    );

  pAVFilterChannelLayouts = ^TAVFilterChannelLayouts;

  TAVFilterChannelLayouts = record

  end;

  pAVFilterPool = ^TAVFilterPool;

  TAVFilterPool = record

  end;

  TAVFilterLink = record
    src: pAVFilterContext;
    /// < source filter
    srcpad: pAVFilterPad;
    /// < output pad on the source filter

    dst: pAVFilterContext;
    /// < dest filter
    dstpad: pAVFilterPad;
    /// < input pad on the dest filter

    _type: TAVMediaType;
    /// < filter media type

    (* These parameters apply only to video *)
    w: integer;
    /// < agreed upon image width
    h: integer;
    /// < agreed upon image height
    sample_aspect_ratio: TAVRational;
    /// < agreed upon sample aspect ratio
    (* These parameters apply only to audio *)
    channel_layout: uint64;
    /// < channel layout of current buffer (see libavutil/channel_layout.h)
    sample_rate: integer;
    /// < samples per second

    format: integer;
    /// < agreed upon media format

    (*
      * Define the time base used by the PTS of the frames/samples
      * which will pass through this link.
      * During the configuration stage, each filter is supposed to
      * change only the output timebase, while the timebase of the
      * input link is assumed to be an unchangeable property.
    *)
    time_base: TAVRational;

    (* ***************************************************************
      * All fields below this line are not part of the public API. They
      * may not be used outside of libavfilter and can be changed and
      * removed at will.
      * New public fields should be added right above.
      *****************************************************************
    *)
    (*
      * Lists of formats and channel layouts supported by the input and output
      * filters respectively. These lists are used for negotiating the format
      * to actually be used, which will be loaded into the format and
      * channel_layout members, above, when chosen.
      *
    *)
    in_formats: pAVFilterFormats;
    out_formats: pAVFilterFormats;

    (*
      * Lists of channel layouts and sample rates used for automatic
      * negotiation.
    *)
    in_samplerates: pAVFilterFormats;
    out_samplerates: pAVFilterFormats;
    in_channel_layouts: pAVFilterChannelLayouts;
    out_channel_layouts: pAVFilterChannelLayouts;

    (*
      * Audio only, the destination filter sets this to a non-zero value to
      * request that buffers with the given number of samples should be sent to
      * it. AVFilterPad.needs_fifo must also be set on the corresponding input
      * pad.
      * Last buffer before EOF will be padded with silence.
    *)
    request_samples: integer;

    (* stage of the initialization of the link properties (dimensions, etc) *)
    // enum {
    // AVLINK_UNINIT = 0,      ///< not started
    // AVLINK_STARTINIT,       ///< started, but incomplete
    // AVLINK_INIT             ///< complete
    // } init_state;
    init_state: Tinit_state;

    pool: pAVFilterPool;

    (*
      * Graph the filter belongs to.
    *)
    graph: pAVFilterGraph;

    (*
      * Current timestamp of the link, as defined by the most recent
      * frame(s), in AV_TIME_BASE units.
    *)
    current_pts: int64;

    (*
      * Index in the age array.
    *)
    age_index: integer;

    (*
      * Frame rate of the stream on the link, or 1/0 if unknown;
      * if left to 0/0, will be automatically be copied from the first input
      * of the source filter if it exists.
      *
      * Sources should set it to the best estimation of the real frame rate.
      * Filters should update it if necessary depending on their function.
      * Sinks can use it to set a default output frame rate.
      * It is similar to the r_frame_rate field in AVStream.
    *)
    frame_rate: TAVRational;

    (*
      * Buffer partially filled with samples to achieve a fixed/minimum size.
    *)
    partial_buf: pAVFrame;

    (*
      * Size of the partial buffer to allocate.
      * Must be between min_samples and max_samples.
    *)
    partial_buf_size: integer;

    (*
      * Minimum number of samples to filter at once. If filter_frame() is
      * called with fewer samples, it will accumulate them in partial_buf.
      * This field and the related ones must not be changed after filtering
      * has started.
      * If 0, all related fields are ignored.
    *)
    min_samples: integer;

    (*
      * Maximum number of samples to filter at once. If filter_frame() is
      * called with more samples, it will split them.
    *)
    max_samples: integer;

    (*
      * The buffer reference currently being received across the link by the
      * destination filter. This is used internally by the filter system to
      * allow automatic copying of buffers which do not have sufficient
      * permissions for the destination. This should not be accessed directly
      * by the filters.
    *)
    cur_buf_copy: pAVFilterBufferRef;

    (*
      * True if the link is closed.
      * If set, all attemps of start_frame, filter_frame or request_frame
      * will fail with AVERROR_EOF, and if necessary the reference will be
      * destroyed.
      * If request_frame returns AVERROR_EOF, this flag is set on the
      * corresponding link.
      * It can be set also be set by either the source or the destination
      * filter.
    *)
    closed: integer;

    (*
      * Number of channels.
    *)
    channels: integer;

    (*
      * True if a frame is being requested on the link.
      * Used internally by the framework.
    *)
    frame_requested: cardinal;

    (*
      * Link processing flags.
    *)
    flags: cardinal;

    (*
      * Number of past frames sent through the link.
    *)
    frame_count: int64;
  end;


  // (*
  // * Link two filters together.
  // *
  // * @param src    the source filter
  // * @param srcpad index of the output pad on the source filter
  // * @param dst    the destination filter
  // * @param dstpad index of the input pad on the destination filter
  // * @return       zero on success
  // *)
  // int avfilter_link(AVFilterContext * src, unsigned srcpad, AVFilterContext * dst, unsigned dstpad);
  //
  // (*
  // * Free the link in *link, and set its pointer to NULL.
  // *)
  // void avfilter_link_free(AVFilterLink * * link);
  //
  // (*
  // * Get the number of channels of a link.
  // *)
  // int avfilter_link_get_channels(AVFilterLink * link);
  //
  // (*
  // * Set the closed field of a link.
  // *)
  // void avfilter_link_set_closed(AVFilterLink * link, int closed);
  //
  // (*
  // * Negotiate the media format, dimensions, etc of all inputs to a filter.
  // *
  // * @param filter the filter to negotiate the properties for its inputs
  // * @return       zero on successful negotiation
  // *)
  // int avfilter_config_links(AVFilterContext * filter);
  //
  // #
  // if FF_API_AVFILTERBUFFER
  // (*
  // * Create a buffer reference wrapped around an already allocated image
  // * buffer.
  // *
  // * @param data pointers to the planes of the image to reference
  // * @param linesize linesizes for the planes of the image to reference
  // * @param perms the required access permissions
  // * @param w the width of the image specified by the data and linesize arrays
  // * @param h the height of the image specified by the data and linesize arrays
  // * @param format the pixel format of the image specified by the data and linesize arrays
  // *)
  // attribute_deprecated AVFilterBufferRef * avfilter_get_video_buffer_ref_from_arrays(uint8_t * const data[4], const int linesize[4],
  // int perms, int w, int h, enum AVPixelFormat format);
  //
  // (*
  // * Create an audio buffer reference wrapped around an already
  // * allocated samples buffer.
  // *
  // * See avfilter_get_audio_buffer_ref_from_arrays_channels() for a version
  // * that can handle unknown channel layouts.
  // *
  // * @param data           pointers to the samples plane buffers
  // * @param linesize       linesize for the samples plane buffers
  // * @param perms          the required access permissions
  // * @param nb_samples     number of samples per channel
  // * @param sample_fmt     the format of each sample in the buffer to allocate
  // * @param channel_layout the channel layout of the buffer
  // *)
  // attribute_deprecated AVFilterBufferRef * avfilter_get_audio_buffer_ref_from_arrays(uint8_t * * data, int linesize, int perms,
  // int nb_samples, enum AVSampleFormat sample_fmt, uint64_t channel_layout);
  // (*
  // * Create an audio buffer reference wrapped around an already
  // * allocated samples buffer.
  // *
  // * @param data           pointers to the samples plane buffers
  // * @param linesize       linesize for the samples plane buffers
  // * @param perms          the required access permissions
  // * @param nb_samples     number of samples per channel
  // * @param sample_fmt     the format of each sample in the buffer to allocate
  // * @param channels       the number of channels of the buffer
  // * @param channel_layout the channel layout of the buffer,
  // *                       must be either 0 or consistent with channels
  // *)
  // attribute_deprecated AVFilterBufferRef * avfilter_get_audio_buffer_ref_from_arrays_channels(uint8_t * * data, int linesize, int perms,
  // int nb_samples, enum AVSampleFormat sample_fmt, int channels, uint64_t channel_layout);
  //
  // # endif
  //
  // # define AVFILTER_CMD_FLAG_ONE 1
  /// // < Stop once a filter understood the command (for target=all for example), fast filters are favored automatically
  // # define AVFILTER_CMD_FLAG_FAST 2
  /// // < Only execute command when its fast (like a video out that supports contrast adjustment in hw)
  //
  // (*
  // * Make the filter instance process a command.
  // * It is recommended to use avfilter_graph_send_command().
  // *)
  // int avfilter_process_command(AVFilterContext * filter, const char * cmd, const char * arg, char * res, int res_len, int flags);


  // #
  // if FF_API_OLD_FILTER_REGISTER
  // (* Uninitialize the filter system. Unregister all filters. *)
  // attribute_deprecated void avfilter_uninit(void);
  // # endif
  //
  // (*
  // * Register a filter. This is only needed if you plan to use
  // * avfilter_get_by_name later to lookup the AVFilter structure by name. A
  // * filter can still by instantiated with avfilter_graph_alloc_filter even if it
  // * is not registered.
  // *
  // * @param filter the filter to register
  // * @return 0 if the registration was successful, a negative value
  // * otherwise
  // *)
  // int avfilter_register(avfilter * filter);

  // (*
  // * Iterate over all registered filters.
  // * @return If prev is non-NULL, next registered filter after prev or NULL if
  // * prev is the last filter. If prev is NULL, return the first registered filter.
  // *)
  // const
  // avfilter * avfilter_next(const avfilter * prev);
  //
  // #
  // if FF_API_OLD_FILTER_REGISTER
  // (*
  // * If filter is NULL, returns a pointer to the first registered filter pointer,
  // * if filter is non-NULL, returns the next pointer after filter.
  // * If the returned pointer points to NULL, the last registered filter
  // * was already reached.
  // * @deprecated use avfilter_next()
  // *)
  // attribute_deprecated avfilter * * av_filter_next(avfilter * * filter);
  // # endif
  //
  // #
  // if FF_API_AVFILTER_OPEN
  // (*
  // * Create a filter instance.
  // *
  // * @param filter_ctx put here a pointer to the created filter context
  // * on success, NULL on failure
  // * @param filter    the filter to create an instance of
  // * @param inst_name Name to give to the new instance. Can be NULL for none.
  // * @return >= 0 in case of success, a negative error code otherwise
  // * @deprecated use avfilter_graph_alloc_filter() instead
  // *)
  // attribute_deprecated int avfilter_open(AVFilterContext * * filter_ctx, avfilter * filter, const char * inst_name);
  // # endif
  //
  // #
  // if FF_API_AVFILTER_INIT_FILTER
  // (*
  // * Initialize a filter.
  // *
  // * @param filter the filter to initialize
  // * @param args   A string of parameters to use when initializing the filter.
  // *               The format and meaning of this string varies by filter.
  // * @param opaque Any extra non-string data needed by the filter. The meaning
  // *               of this parameter varies by filter.
  // * @return       zero on success
  // *)
  // attribute_deprecated int avfilter_init_filter(AVFilterContext * filter, const char * args, void * opaque);
  // # endif
  //
  // (*
  // * Initialize a filter with the supplied parameters.
  // *
  // * @param ctx  uninitialized filter context to initialize
  // * @param args Options to initialize the filter with. This must be a
  // *             ':'-separated list of options in the 'key=value' form.
  // *             May be NULL if the options have been set directly using the
  // *             AVOptions API or there are no options that need to be set.
  // * @return 0 on success, a negative AVERROR on failure
  // *)
  // int avfilter_init_str(AVFilterContext * ctx, const char * args);
  //
  // (*
  // * Initialize a filter with the supplied dictionary of options.
  // *
  // * @param ctx     uninitialized filter context to initialize
  // * @param options An AVDictionary filled with options for this filter. On
  // *                return this parameter will be destroyed and replaced with
  // *                a dict containing options that were not found. This dictionary
  // *                must be freed by the caller.
  // *                May be NULL, then this function is equivalent to
  // *                avfilter_init_str() with the second parameter set to NULL.
  // * @return 0 on success, a negative AVERROR on failure
  // *
  // * @note This function and avfilter_init_str() do essentially the same thing,
  // * the difference is in manner in which the options are passed. It is up to the
  // * calling code to choose whichever is more preferable. The two functions also
  // * behave differently when some of the provided options are not declared as
  // * supported by the filter. In such a case, avfilter_init_str() will fail, but
  // * this function will leave those extra options in the options AVDictionary and
  // * continue as usual.
  // *)
  // int avfilter_init_dict(AVFilterContext * ctx, AVDictionary * * options);
  //
  // (*
  // * Free a filter context. This will also remove the filter from its
  // * filtergraph's list of filters.
  // *
  // * @param filter the filter to free
  // *)
  // void avfilter_free(AVFilterContext * filter);
  //
  // (*
  // * Insert a filter in the middle of an existing link.
  // *
  // * @param link the link into which the filter should be inserted
  // * @param filt the filter to be inserted
  // * @param filt_srcpad_idx the input pad on the filter to connect
  // * @param filt_dstpad_idx the output pad on the filter to connect
  // * @return     zero on success
  // *)
  // int avfilter_insert_filter(AVFilterLink * link, AVFilterContext * filt, unsigned filt_srcpad_idx, unsigned filt_dstpad_idx);
  //
  // #
  // if FF_API_AVFILTERBUFFER
  // (*
  // * Copy the frame properties of src to dst, without copying the actual
  // * image data.
  // *
  // * @return 0 on success, a negative number on error.
  // *)
  // attribute_deprecated int avfilter_copy_frame_props(AVFilterBufferRef * dst, const AVFrame * src);
  //
  // (*
  // * Copy the frame properties and data pointers of src to dst, without copying
  // * the actual data.
  // *
  // * @return 0 on success, a negative number on error.
  // *)
  // attribute_deprecated int avfilter_copy_buf_props(AVFrame * dst, const AVFilterBufferRef * src);
  // # endif
  //
  // (*
  // * @return AVClass for AVFilterContext.
  // *
  // * @see av_opt_find().
  // *)
  // const
  // AVClass * avfilter_get_class(void);

  pAVFilterGraphInternal = ^TAVFilterGraphInternal;

  TAVFilterGraphInternal = record

  end;

  //
  // (*
  // * A function pointer passed to the @ref AVFilterGraph.execute callback to be
  // * executed multiple times, possibly in parallel.
  // *
  // * @param ctx the filter context the job belongs to
  // * @param arg an opaque parameter passed through from @ref
  // *            AVFilterGraph.execute
  // * @param jobnr the index of the job being executed
  // * @param nb_jobs the total number of jobs
  // *
  // * @return 0 on success, a negative AVERROR on error
  // *)
  // typedef int(avfilter_action_func)(AVFilterContext * ctx, void * arg, int jobnr, int nb_jobs);
  Tavfilter_action_func = function(ctx: pAVFilterContext; arg: pointer; jobnr: integer; nb_jobs: integer): integer; cdecl;
  // (*
  // * A function executing multiple jobs, possibly in parallel.
  // *
  // * @param ctx the filter context to which the jobs belong
  // * @param func the function to be called multiple times
  // * @param arg the argument to be passed to func
  // * @param ret a nb_jobs-sized array to be filled with return values from each
  // *            invocation of func
  // * @param nb_jobs the number of jobs to execute
  // *
  // * @return 0 on success, a negative AVERROR on error
  // *)
  // typedef int(avfilter_execute_func)(AVFilterContext * ctx, avfilter_action_func * func, void * arg, int * ret, int nb_jobs);
  Tavfilter_execute_func = function(ctx: pAVFilterContext; func: Tavfilter_action_func; arg: pointer; var ret: integer; nb_jobs: integer)
    : integer; cdecl;

  TAVFilterGraph = record
    av_class: pAVClass;
{$IFDEF FF_API_FOO_COUNT}
    // attribute_deprecated
    // unsigned filter_count_unused;
    filter_count_unused: cardinal;
{$ENDIF}
    filters: PPMonitor;
{$IFNDEF FF_API_FOO_COUNT}
    nb_filters: cardinal;
{$ENDIF}
    scale_sws_opts: pAnsiChar;
    /// < sws options to use for the auto-inserted scale filters
    resample_lavr_opts: pAnsiChar;
    /// < libavresample options to use for the auto-inserted resample filters
{$IFDEF FF_API_FOO_COUNT}
    nb_filters: cardinal;
{$ENDIF}
    (*
      * Type of multithreading allowed for filters in this graph. A combination
      * of AVFILTER_THREAD_* flags.
      *
      * May be set by the caller at any point, the setting will apply to all
      * filters initialized after that. The default is allowing everything.
      *
      * When a filter in this graph is initialized, this field is combined using
      * bit AND with AVFilterContext.thread_type to get the final mask used for
      * determining allowed threading types. I.e. a threading type needs to be
      * set in both to be allowed.
    *)
    thread_type: integer;
    (*
      * Maximum number of threads used by filters in this graph. May be set by
      * the caller before adding any filters to the filtergraph. Zero (the
      * default) means that the number of threads is determined automatically.
    *)
    nb_threads: integer;
    (*
      * Opaque object for libavfilter internal use.
    *)
    internal: pAVFilterGraphInternal;
    (*
      * Opaque user data. May be set by the caller to an arbitrary value, e.g. to
      * be used from callbacks like @ref AVFilterGraph.execute.
      * Libavfilter will not touch this field in any way.
    *)
    opaque: pointer;
    (*
      * This callback may be set by the caller immediately after allocating the
      * graph and before adding any filters to it, to provide a custom
      * multithreading implementation.
      *
      * If set, filters with slice threading capability will call this callback
      * to execute multiple jobs in parallel.
      *
      * If this field is left unset, libavfilter will use its internal
      * implementation, which may or may not be multithreaded depending on the
      * platform and build options.
    *)
    execute: Tavfilter_execute_func;
    aresample_swr_opts: pAnsiChar;
    /// < swr options to use for the auto-inserted aresample filters, Access ONLY through AVOptions
    (*
      * Private fields
      *
      * The following fields are for internal use only.
      * Their type, offset, number and semantic can change without notice.
    *)
    sink_links: ppAVFilterLink;
    sink_links_count: integer;

    disable_auto_convert: cardinal;
  end;

  (*
    * Allocate a filter graph.
  *)
  // AVFilterGraph * avfilter_graph_alloc(void);
function avfilter_graph_alloc(): pAVFilterGraph; cdecl;

// (*
// * Get a filter definition matching the given name.
// *
// * @param name the filter name to find
// * @return     the filter definition, if any matching one is registered.
// *             NULL if none found.
// *)
// #if ! FF_API_NOCONST_GET_NAME
// const
// #endif
// avfilter * avfilter_get_by_name(const char * name);
function avfilter_get_by_name(const name: pAnsiChar): pavfilter; cdecl;

//
// (*
// * Create a new filter instance in a filter graph.
// *
// * @param graph graph in which the new filter will be used
// * @param filter the filter to create an instance of
// * @param name Name to give to the new instance (will be copied to
// *             AVFilterContext.name). This may be used by the caller to identify
// *             different filters, libavfilter itself assigns no semantics to
// *             this parameter. May be NULL.
// *
// * @return the context of the newly created filter instance (note that it is
// *         also retrievable directly through AVFilterGraph.filters or with
// *         avfilter_graph_get_filter()) on success or NULL or failure.
// *)
// AVFilterContext * avfilter_graph_alloc_filter(AVFilterGraph * graph, const avfilter * filter, const char * name);
//
// (*
// * Get a filter instance with name name from graph.
// *
// * @return the pointer to the found filter instance or NULL if it
// * cannot be found.
// *)
// AVFilterContext * avfilter_graph_get_filter(AVFilterGraph * graph, char * name);
//
// #
// if FF_API_AVFILTER_OPEN
// (*
// * Add an existing filter instance to a filter graph.
// *
// * @param graphctx  the filter graph
// * @param filter the filter to be added
// *
// * @deprecated use avfilter_graph_alloc_filter() to allocate a filter in a
// * filter graph
// *)
// attribute_deprecated int avfilter_graph_add_filter(AVFilterGraph * graphctx, AVFilterContext * filter);
// # endif
//
// (*
// * Create and add a filter instance into an existing graph.
// * The filter instance is created from the filter filt and inited
// * with the parameters args and opaque.
// *
// * In case of success put in *filt_ctx the pointer to the created
// * filter instance, otherwise set *filt_ctx to NULL.
// *
// * @param name the instance name to give to the created filter instance
// * @param graph_ctx the filter graph
// * @return a negative AVERROR error code in case of failure, a non
// * negative value otherwise
// *)
// int avfilter_graph_create_filter(AVFilterContext **filt_ctx, const avfilter * filt, const char * name, const char * args,
// void * opaque, AVFilterGraph * graph_ctx);
function avfilter_graph_create_filter(Var filt_ctx: pAVFilterContext; const filt: pavfilter; const name: pAnsiChar; const args: pAnsiChar;
  opaque: pointer; graph_ctx: pAVFilterGraph): integer; cdecl;
//
// (*
// * Enable or disable automatic format conversion inside the graph.
// *
// * Note that format conversion can still happen inside explicitly inserted
// * scale and aresample filters.
// *
// * @param flags  any of the AVFILTER_AUTO_CONVERT_* constants
// *)
// void avfilter_graph_set_auto_convert(AVFilterGraph * graph, unsigned flags);
//
// enum {
// AVFILTER_AUTO_CONVERT_ALL  =  0, (*< all automatic conversions enabled *)
// AVFILTER_AUTO_CONVERT_NONE = -1, (*< all automatic conversions disabled *)
// };
//
// (*
// * Check validity and configure all the links and formats in the graph.
// *
// * @param graphctx the filter graph
// * @param log_ctx context used for logging
// * @return >= 0 in case of success, a negative AVERROR code otherwise
// *)
// int avfilter_graph_config(AVFilterGraph * graphctx, void * log_ctx);
function avfilter_graph_config(graphctx: pAVFilterGraph; log_ctx: pointer): integer; cdecl;
//
// (*
// * Free a graph, destroy its links, and set *graph to NULL.
// * If *graph is NULL, do nothing.
// *)
// void avfilter_graph_free(AVFilterGraph * * graph);
procedure avfilter_graph_free(Var graph: pAVFilterGraph); cdecl;

type
  (*
    * A linked-list of the inputs/outputs of the filter chain.
    *
    * This is mainly useful for avfilter_graph_parse() / avfilter_graph_parse2(),
    * where it is used to communicate open (unlinked) inputs and outputs from and
    * to the caller.
    * This struct specifies, per each not connected pad contained in the graph, the
    * filter context and the pad index required for establishing a link.
  *)
  pAVFilterInOut = ^TAVFilterInOut;

  TAVFilterInOut = record
    (* unique name for this input/output in the list *)
    name: pAnsiChar;

    (* filter context associated to this input/output *)
    filter_ctx: pAVFilterContext;

    (* index of the filt_ctx pad to use for linking *)
    pad_idx: integer;

    (* next input/input in the list, NULL if this is the last *)
    next: pAVFilterInOut;
  end;

  // (* Initialize the filter system. Register all builtin filters. *)
  // void avfilter_register_all(void);
procedure avfilter_register_all(); cdecl;

// (*
// * Allocate a single AVFilterInOut entry.
// * Must be freed with avfilter_inout_free().
// * @return allocated AVFilterInOut on success, NULL on failure.
// *)
// AVFilterInOut * avfilter_inout_alloc(void);
function avfilter_inout_alloc(): pAVFilterInOut; cdecl;
// (*
// * Free the supplied list of AVFilterInOut and set *inout to NULL.
// * If *inout is NULL, do nothing.
// *)
// void avfilter_inout_free(AVFilterInOut * * inout);
//
// #
// if AV_HAVE_INCOMPATIBLE_LIBAV_ABI | | ! FF_API_OLD_GRAPH_PARSE
// (*
// * Add a graph described by a string to a graph.
// *
// * @note The caller must provide the lists of inputs and outputs,
// * which therefore must be known before calling the function.
// *
// * @note The inputs parameter describes inputs of the already existing
// * part of the graph; i.e. from the point of view of the newly created
// * part, they are outputs. Similarly the outputs parameter describes
// * outputs of the already existing filters, which are provided as
// * inputs to the parsed filters.
// *
// * @param graph   the filter graph where to link the parsed grap context
// * @param filters string to be parsed
// * @param inputs  linked list to the inputs of the graph
// * @param outputs linked list to the outputs of the graph
// * @return zero on success, a negative AVERROR code on error
// *)
// int avfilter_graph_parse(AVFilterGraph * graph, const char * filters, AVFilterInOut * inputs, AVFilterInOut * outputs, void * log_ctx);
// #
// else
// (*
// * Add a graph described by a string to a graph.
// *
// * @param graph   the filter graph where to link the parsed graph context
// * @param filters string to be parsed
// * @param inputs  pointer to a linked list to the inputs of the graph, may be NULL.
// *                If non-NULL, *inputs is updated to contain the list of open inputs
// *                after the parsing, should be freed with avfilter_inout_free().
// * @param outputs pointer to a linked list to the outputs of the graph, may be NULL.
// *                If non-NULL, *outputs is updated to contain the list of open outputs
// *                after the parsing, should be freed with avfilter_inout_free().
// * @return non negative on success, a negative AVERROR code on error
// * @deprecated Use avfilter_graph_parse_ptr() instead.
// *)
// attribute_deprecated int avfilter_graph_parse(AVFilterGraph * graph, const char * filters, AVFilterInOut * * inputs,
// AVFilterInOut * * outputs, void * log_ctx);
// # endif
//
// (*
// * Add a graph described by a string to a graph.
// *
// * @param graph   the filter graph where to link the parsed graph context
// * @param filters string to be parsed
// * @param inputs  pointer to a linked list to the inputs of the graph, may be NULL.
// *                If non-NULL, *inputs is updated to contain the list of open inputs
// *                after the parsing, should be freed with avfilter_inout_free().
// * @param outputs pointer to a linked list to the outputs of the graph, may be NULL.
// *                If non-NULL, *outputs is updated to contain the list of open outputs
// *                after the parsing, should be freed with avfilter_inout_free().
// * @return non negative on success, a negative AVERROR code on error
// *)
// int avfilter_graph_parse_ptr(AVFilterGraph * graph, const char * filters, AVFilterInOut * * inputs, AVFilterInOut * * outputs,
// void * log_ctx);
function avfilter_graph_parse_ptr(graph: pAVFilterGraph; const filters: pAnsiChar; Var inputs: pAVFilterInOut; Var outputs: pAVFilterInOut;
  log_ctx: pointer): integer; cdecl;
//
// (*
// * Add a graph described by a string to a graph.
// *
// * @param[in]  graph   the filter graph where to link the parsed graph context
// * @param[in]  filters string to be parsed
// * @param[out] inputs  a linked list of all free (unlinked) inputs of the
// *                     parsed graph will be returned here. It is to be freed
// *                     by the caller using avfilter_inout_free().
// * @param[out] outputs a linked list of all free (unlinked) outputs of the
// *                     parsed graph will be returned here. It is to be freed by the
// *                     caller using avfilter_inout_free().
// * @return zero on success, a negative AVERROR code on error
// *
// * @note This function returns the inputs and outputs that are left
// * unlinked after parsing the graph and the caller then deals with
// * them.
// * @note This function makes no reference whatsoever to already
// * existing parts of the graph and the inputs parameter will on return
// * contain inputs of the newly parsed part of the graph.  Analogously
// * the outputs parameter will contain outputs of the newly created
// * filters.
// *)
// int avfilter_graph_parse2(AVFilterGraph * graph, const char * filters, AVFilterInOut * * inputs, AVFilterInOut * * outputs);
//
// (*
// * Send a command to one or more filter instances.
// *
// * @param graph  the filter graph
// * @param target the filter(s) to which the command should be sent
// *               "all" sends to all filters
// *               otherwise it can be a filter or filter instance name
// *               which will send the command to all matching filters.
// * @param cmd    the command to send, for handling simplicity all commands must be alphanumeric only
// * @param arg    the argument for the command
// * @param res    a buffer with size res_size where the filter(s) can return a response.
// *
// * @returns >=0 on success otherwise an error code.
// *              AVERROR(ENOSYS) on unsupported commands
// *)
// int avfilter_graph_send_command(AVFilterGraph * graph, const char * target, const char * cmd, const char * arg, char * res, int res_len,
// int flags);
//
// (*
// * Queue a command for one or more filter instances.
// *
// * @param graph  the filter graph
// * @param target the filter(s) to which the command should be sent
// *               "all" sends to all filters
// *               otherwise it can be a filter or filter instance name
// *               which will send the command to all matching filters.
// * @param cmd    the command to sent, for handling simplicity all commands must be alphanummeric only
// * @param arg    the argument for the command
// * @param ts     time at which the command should be sent to the filter
// *
// * @note As this executes commands after this function returns, no return code
// *       from the filter is provided, also AVFILTER_CMD_FLAG_ONE is not supported.
// *)
// int avfilter_graph_queue_command(AVFilterGraph * graph, const char * target, const char * cmd, const char * arg, int flags, double ts);
//
// (*
// * Dump a graph into a human-readable string representation.
// *
// * @param graph    the graph to dump
// * @param options  formatting options; currently ignored
// * @return  a string, or NULL in case of memory allocation failure;
// *          the string must be freed using av_free
// *)
// char * avfilter_graph_dump(AVFilterGraph * graph, const char * options);
//
// (*
// * Request a frame on the oldest sink link.
// *
// * If the request returns AVERROR_EOF, try the next.
// *
// * Note that this function is not meant to be the sole scheduling mechanism
// * of a filtergraph, only a convenience function to help drain a filtergraph
// * in a balanced way under normal circumstances.
// *
// * Also note that AVERROR_EOF does not mean that frames did not arrive on
// * some of the sinks during the process.
// * When there are multiple sink links, in case the requested link
// * returns an EOF, this may cause a filter to flush pending frames
// * which are sent to another sink link, although unrequested.
// *
// * @return  the return value of ff_request_frame(),
// *          or AVERROR_EOF if all links returned AVERROR_EOF
// *)
// int avfilter_graph_request_oldest(AVFilterGraph * graph);

implementation

uses ffm.lib;

function avfilter_get_by_name; external avfilter_dll;
function avfilter_inout_alloc; external avfilter_dll;
function avfilter_graph_alloc; external avfilter_dll;
function avfilter_graph_create_filter; external avfilter_dll;
function avfilter_graph_parse_ptr; external avfilter_dll;
function avfilter_graph_config; external avfilter_dll;
procedure avfilter_register_all; external avfilter_dll;
procedure avfilter_graph_free; external avfilter_dll;

end.
