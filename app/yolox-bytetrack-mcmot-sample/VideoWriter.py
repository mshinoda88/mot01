#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
import cv2
import copy

# 動画出力管理
class VideoWriter(object):
    ## カメラ準備 ##
    def __init__(self, args, cap_device, cap_width, cap_height, classes):
        cap = cv2.VideoCapture(cap_device)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, cap_width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, cap_height)
        self.cap_fps = cap.get(cv2.CAP_PROP_FPS)
        self.coco_classes = classes

        # フォーマット・解像度・FPSの取得
        fourcc = decode_fourcc(cap.get(cv2.CAP_PROP_FOURCC))
        width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
        height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
        fps = cap.get(cv2.CAP_PROP_FPS)
        print("fourcc:{} fps:{}　width:{}　height:{}".format(fourcc, fps, width, height))

        # 出力ファイル
        if args.movie is not None:
            self.outpath = os.path.splitext(args.movie)[0] + "_tracked.webm"
        else:
            self.outpath = "camera.webm"

        self.writer = cv2.VideoWriter(
            self.outpath,
            cv2.VideoWriter_fourcc(*'vp80'),
            self.cap_fps, (cap_width, cap_height)
        )
        self.cap = cap


    def get_fps(self):
        return self.cap_fps


    def read_cap(self):
        ret, frame = self.cap.read()
        if not ret:
            self.close()
        return ret, frame


    def close(self):
        self.cap.release()
        self.writer.release()


    def draw_debug(self,
        image,
        elapsed_time,
        score_th,
        trakcer_ids,
        bboxes,
        scores,
        class_ids,
        track_id_dict,
        tracker_id_frames,
    ):
        debug_image = copy.deepcopy(image)

        for tracker_id, bbox, score, class_id in zip(trakcer_ids, bboxes, scores,
                                                    class_ids):
            x1, y1, x2, y2 = int(bbox[0]), int(bbox[1]), int(bbox[2]), int(bbox[3])

            if score_th > score:
                continue

            color = get_id_color(int(track_id_dict[tracker_id]))

            # バウンディングボックス
            debug_image = cv2.rectangle(
                debug_image,
                (x1, y1),
                (x2, y2),
                color,
                thickness=2,
            )

            # トラックID、スコア
            score_txt = str(round(score, 2))
            text = 'Track ID:%s(%s)' % (int(track_id_dict[tracker_id]), score_txt)
            debug_image = cv2.putText(
                debug_image,
                text,
                (x1, y1 - 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                color,
                thickness=2,
            )
            # クラスID
            text = 'Class ID:%s(%s)' % (class_id, self.coco_classes[class_id])
            debug_image = cv2.putText(
                debug_image,
                text,
                (x1, y1 - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                color,
                thickness=2,
            )

            # ID別のフレームを記録
            crop = debug_image[max(y1-30,0):y2, x1:x2, :]
            if not tracker_id in tracker_id_frames.keys():
                tracker_id_frames[tracker_id] = [crop]
            else:
                tracker_id_frames[tracker_id].append(crop)

        # 推論時間
        text = 'Elapsed time:' + '%.0f' % (elapsed_time * 1000)
        text = text + 'ms'
        debug_image = cv2.putText(
            debug_image,
            text,
            (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (0, 255, 0),
            thickness=2,
        )

        # 書き込み
        self.writer.write(debug_image)

        return debug_image


    # トラッキング結果の動画生成
    def write_track_id_wise_video(self,
        track_id_frames_dict,
        cap_fps
    ):
        base_dir = self.outpath.replace(".webm", "")
        if not os.path.exists(base_dir):
            os.makedirs(base_dir)

        for track_id, track_frames in track_id_frames_dict.items():
            width, height = 0, 0
            for frame in track_frames:
                height = max(frame.shape[0], height)
                width = max(frame.shape[1], width)

            writer = cv2.VideoWriter(
                f"{base_dir}/{track_id}.webm",
                cv2.VideoWriter_fourcc(*'vp80'),
                cap_fps, (width, height)
            )
            for frame in track_frames:
                pad_left = (width - frame.shape[1])//2
                pad_right = width - frame.shape[1] - pad_left
                pad_top = (height - frame.shape[0])//2
                pad_bottom = height - frame.shape[0] - pad_top
                frame_pad = cv2.copyMakeBorder(frame, 
                                pad_top, pad_bottom, pad_left, pad_right, 
                                cv2.BORDER_CONSTANT, (0, 0, 0))
                writer.write(frame_pad)
            writer.release()


def decode_fourcc(v):
        v = int(v)
        return "".join([chr((v >> 8 * i) & 0xFF) for i in range(4)])


def get_id_color(index):
    temp_index = abs(int(index)) * 3
    color = ((37 * temp_index) % 255, (17 * temp_index) % 255,
             (29 * temp_index) % 255)
    return color

